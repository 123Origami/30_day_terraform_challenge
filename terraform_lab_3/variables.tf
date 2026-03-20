variable "aws_region" {
  description = "AWS region to be used in plan"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance to be deployed"
  type        = string
  default     = "t3.micro"
}

variable "server_port" {
  description = "port the web server will listen on"
  type        = number
  default     = "80"
}

variable "ssh_port" {
  description = "the port servers can ssh into"
  type        = number
  default     = "22"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the server"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Warning: In production, restrict this!
}

variable "http_cidr_blocks" {
  description = "CIDR blocks allowed to access the web server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "project_name" {
  description = "Name of the project for tagging"
  type        = string
  default     = "30-days-terraform"
}

# variables.tf (add these to your existing variables)

# Auto Scaling Group variables
variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 5
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 2
}

