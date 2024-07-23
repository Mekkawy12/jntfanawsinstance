provider "aws" {
  region = "eu-north-1"
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create Subnets
resource "aws_subnet" "subnet_a" {
  vpc_id             = aws_vpc.main.id
  cidr_block         = "10.0.1.0/24"
  availability_zone  = "us-east-1a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id             = aws_vpc.main.id
  cidr_block         = "10.0.2.0/24"
  availability_zone  = "us-east-1b"
}

# Security Group for EC2 instances
resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

# Launch Template
resource "aws_launch_template" "example" {
  name_prefix   = "example-"
  image_id      = "ami-0d7e17c1a01e6fa40"  # Replace with your desired AMI ID
  instance_type = "t3.micro"
  key_name      = MyKeyPair

  network_interfaces {
    security_groups = [aws_security_group.instance_sg.id]
    associate_public_ip_address = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "instance group machine"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "example" {
  vpc_zone_identifier = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  desired_capacity    = 2
  max_size            = 2
  min_size            = 1
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "instance group"
    propagate_at_launch = true
  }

  # Attach to the Load Balancer
  target_group_arns = [aws_lb_target_group.example.arn]
}

# Load Balancer
resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instance_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  enable_deletion_protection = false
}

# Target Group
resource "aws_lb_target_group" "example" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }
}

# Listener
resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

output "lb_dns_name" {
  value = aws_lb.example.dns_name
}
