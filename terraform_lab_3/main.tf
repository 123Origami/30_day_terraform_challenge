#indicates the cloud service that I am using for this challenge
provider "aws" {
  region = "eu-north-1"
  #credentials set in environment variables for security
}

#security group block, acts as a firewall for our ec2 instance

resource "aws_security_group" "web_server_sg" {
  name        = "day_3 web server sg"
  description = "allow http traffic into web server"

  #inbound rule: allow port 80 from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #anyone can access
  }

  #inbound rule: allow ssh for debugging

  ingress {
    description = "SSH from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In production, restrict to your IP!
  }

  # outbound rule:allow all outbound traffic

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # means all protocols allowed
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "day-3-web-server-sg"
    Day  = 3
  }

}

#data source to get the latest linux ami

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# the actual server
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  # Attach the security group created above
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  # ensure the instance gets a public id
  associate_public_ip_address = true

  # User data script - Runs when the instance starts
  # This installs Apache and creates a custom webpage
  user_data = <<-EOF
    #!/bin/bash
    # Update the system
    yum update -y
    
    # Install Apache web server
    yum install -y httpd
    
    # Start Apache and enable it to start on boot
    systemctl start httpd
    systemctl enable httpd
    
    # Create a custom HTML page for Day 3 challenge
    cat > /var/www/html/index.html << 'ENDHTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Terraform Day 3 Challenge</title>
        <style>
            body {
                font-family: 'Arial', sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                text-align: center;
                padding: 50px;
                margin: 0;
                height: 100vh;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
            }
            h1 {
                font-size: 3em;
                margin-bottom: 20px;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }
            .success-box {
                background: rgba(255,255,255,0.1);
                padding: 30px;
                border-radius: 15px;
                backdrop-filter: blur(5px);
                border: 1px solid rgba(255,255,255,0.2);
                max-width: 600px;
            }
            .date {
                font-size: 1.2em;
                margin-top: 20px;
                color: #ffd700;
            }
            .ip {
                background: rgba(0,0,0,0.3);
                padding: 10px;
                border-radius: 5px;
                font-family: monospace;
                margin-top: 20px;
            }
        </style>
    </head>
    <body>
        <div class="success-box">
            <h1>🚀 Day 3 Challenge Success!</h1>
            <h2>My First Server Deployed with Terraform</h2>
            <p>This server was provisioned entirely through Infrastructure as Code</p>
            <div class="date">
                Deployed on: $(date)
            </div>
            <div class="ip">
                Server IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
            </div>
            <p style="margin-top: 30px;">
                <small>30-Day Terraform Challenge - Day 3</small>
            </p>
        </div>
    </body>
    </html>
    ENDHTML
    
    # Set proper permissions
    chmod 644 /var/www/html/index.html
    
    # Log completion
    echo "User data script completed at $(date)" >> /var/log/user-data.log
  EOF

  # tag the instance

  tags = {
    Name      = "day3-terraform-web-server"
    Day       = "3"
    Challenge = "30-day-terraform"

  }


}


#Outputs
#used to display important information after deployment

output "web_server_public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.web_server.public_ip
}

output "web_server_url" {
  description = "URL to access the web server"
  value       = "http://${aws_instance.web_server.public_ip}"
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web_server.id
}

output "ssh_connection_command" {
  description = "Command to SSH into the server (if needed)"
  value       = "ssh ec2-user@${aws_instance.web_server.public_ip}"
}
