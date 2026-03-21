# cluster-main.tf

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for VPC (using default VPC for simplicity)
data "aws_vpc" "default" {
  default = true
}

# Data source for subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTP from anywhere
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-alb-sg"
    Environment = var.environment
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "instance_sg" {
  name        = "${var.environment}-instance-sg"
  description = "Security group for EC2 instances behind ALB"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTP only from the ALB security group
  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow SSH for debugging (restrict in production!)
  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-instance-sg"
    Environment = var.environment
  }
}

# Launch Template for instances
resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment}-web-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    
    # Get instance info
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    
    # Create custom HTML page that shows which instance is serving
    cat > /var/www/html/index.html << 'ENDHTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Terraform Day 4 Challenge - Cluster</title>
        <style>
            body {
                font-family: 'Arial', sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                text-align: center;
                padding: 50px;
                margin: 0;
            }
            .container {
                background: rgba(255,255,255,0.1);
                padding: 30px;
                border-radius: 15px;
                max-width: 800px;
                margin: 0 auto;
            }
            .server-info {
                background: rgba(0,0,0,0.3);
                padding: 20px;
                border-radius: 10px;
                margin: 20px 0;
                border-left: 5px solid #ffd700;
            }
            .cluster-badge {
                display: inline-block;
                background: #ffd700;
                color: #333;
                padding: 5px 15px;
                border-radius: 20px;
                font-weight: bold;
                margin-bottom: 20px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <span class="cluster-badge">⚡ High Availability Cluster ⚡</span>
            <h1>🚀 Day 4 Challenge Success!</h1>
            <h2>Load Balanced Web Server Cluster</h2>
            
            <div class="server-info">
                <h3>Currently serving from:</h3>
                <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
                <p><strong>Availability Zone:</strong> $AVAILABILITY_ZONE</p>
                <p><strong>Environment:</strong> ${var.environment}</p>
                <p><strong>Time:</strong> $(date)</p>
            </div>
            
            <p>This request was load balanced across the cluster!</p>
            <p>Try refreshing to see different instances.</p>
            
            <hr style="border-color: rgba(255,255,255,0.2); margin: 30px 0;">
            
            <p><small>30-Day Terraform Challenge - Day 4 - Highly Available Architecture</small></p>
        </div>
    </body>
    </html>
    ENDHTML
    
    chmod 644 /var/www/html/index.html
    echo "User data script completed for instance $INSTANCE_ID at $(date)" >> /var/log/user-data.log
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-web-instance"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "web" {
  name               = "${var.environment}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Day         = "5"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "web" {
  name     = "${var.environment}-web-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    port                = var.server_port
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Listener for ALB
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = var.server_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                      = "${var.environment}-web-asg"
  vpc_zone_identifier       = data.aws_subnets.default.ids
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-web-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  # This ensures the ASG replaces instances when the launch template changes
  lifecycle {
    create_before_destroy = true
  }
}

# Outputs for the cluster
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.web.dns_name
}

output "alb_url" {
  description = "URL to access the web cluster"
  value       = "http://${aws_lb.web.dns_name}:${var.server_port}"
}

output "asg_info" {
  description = "Auto Scaling Group information"
  value = {
    min_size         = aws_autoscaling_group.web.min_size
    max_size         = aws_autoscaling_group.web.max_size
    desired_capacity = aws_autoscaling_group.web.desired_capacity
  }
}

output "availability_zones_used" {
  description = "Availability zones where instances are deployed"
  value       = data.aws_availability_zones.available.names
}

# Data source to count running instances
data "aws_instances" "web_instances" {
  depends_on = [aws_autoscaling_group.web]

  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Output for instance count - shows scaling is working
output "running_instances_count" {
  description = "Number of running instances"
  value       = length(data.aws_instances.web_instances.ids)
}
