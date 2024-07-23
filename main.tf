provider "aws" {
  region = "eu-north-1"
}



# Security Group for EC2 instances
resource "aws_security_group" "instance_sg" {
  vpc_id = "vpc-0f104f618f5765701"

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
  key_name      = "MyKeyPair"
  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install git -y
    EOF
    )

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
  vpc_zone_identifier = ["subnet-0ab186223db9ed82f", "subnet-0369760ebd3d3a70e"]
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
  subnets            = ["subnet-0ab186223db9ed82f", "subnet-0369760ebd3d3a70e"]

  enable_deletion_protection = false
}

# Target Group
resource "aws_lb_target_group" "example" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0f104f618f5765701"

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

output "target_group_arn" {
  value = aws_lb_target_group.example.arn
}

