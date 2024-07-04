### Terraform Configuration

#### `main.tf`
provider "aws" {
  region = "us-west-2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.10.0"

  name                 = "production-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  tags = {
    Terraform = "true"
    Environment = "production"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform = "true"
    Environment = "production"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For production, restrict to specific IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform = "true"
    Environment = "production"
  }
}

resource "aws_alb" "app_alb" {
  name            = "app-alb"
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets         = module.vpc.public_subnets

  enable_deletion_protection = true

  tags = {
    Terraform = "true"
    Environment = "production"
  }
}

resource "aws_alb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    Terraform = "true"
    Environment = "production"
  }
}

resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = aws_alb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.app_tg.arn
  }
}

resource "aws_launch_configuration" "app_lc" {
  name          = "app-lc"
  image_id      = "ami-12345678"  # Replace with your AMI ID
  instance_type = "t3.micro"

  security_groups = [aws_security_group.ec2_sg.id]

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo amazon-linux-extras install -y nginx1
              sudo systemctl start nginx
              EOF

  tags = {
    Terraform = "true"
    Environment = "production"
  }
}

resource "aws_autoscaling_group" "app_asg" {
  desired_capacity     = 2
  max_size             = 4
  min_size             = 2
  vpc_zone_identifier  = module.vpc.private_subnets
  launch_configuration = aws_launch_configuration.app_lc.id

  target_group_arns = [aws_alb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }

  tags = {
    Terraform = "true"
    Environment = "production"
  }
}
