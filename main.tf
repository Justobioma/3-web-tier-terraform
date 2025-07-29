# Basic VPC and Subnet Setup for Web Tier

resource "aws_vpc" "web_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "web-tier-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.web_vpc.id
}

resource "aws_subnet" "public_subnet" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.web_vpc.id
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1a"

  tags = {
    Name = "web-tier-public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.web_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# RDS Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet_a.id,
    aws_subnet.private_subnet_b.id
  ]

  tags = {
    Name = "db-subnet-group"
  }
}

# Security Group for Web Tier

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH access"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Optional: limit this to your IP for SSH
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

  tags = {
    Name = "web-tier-sg"
  }
}

# Security Group for RDS(Database)

resource "aws_security_group" "db_sg" {
  name        = "db-tier-sg"
  description = "Allow DB access from App tier only"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    from_port       = 3306 # change if using PostgreSQL (5432)
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-tier-sg"
  }
}

# EC2 Instance for Web Tier Setup

resource "aws_instance" "web_server" {
  ami                    = "ami-01f23391a59163da9" # Replace with a dynamic AMI later
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = "obioma-key" # Replace with your actual key pair
  vpc_security_group_ids = [aws_security_group.web_sg.id]

    user_data = <<EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt install nginx -y
  sudo systemctl enable nginx
  sudo systemctl start nginx
  EOF

  tags = {
    Name = "web-tier-server"
  }
}

resource "aws_eip" "web_eip" {
  instance = aws_instance.web_server.id
 // vpc      = true
}

# Output parameters
output "web_server_ip" {
  value = aws_eip.web_eip.public_ip
}

output "web_server_id" {
  value = aws_instance.web_server.id
}

# DB Endpoint Output
output "db_endpoint" {
  value = aws_db_instance.app_db.endpoint
}

# Private Subnets for App Tier
resource "aws_subnet" "private_subnet_a" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "app-tier-private-subnet-a" 
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "app-tier-private-subnet-b"
  }
}

# NAT Gateway for Private Subnets

resource "aws_eip" "nat_eip" {
  //vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id  # must be public!
  tags = {
    Name = "nat-gateway"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.web_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "app-tier-private-rt"
  }
}

resource "aws_route_table_association" "private_rt_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rt_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

# Backend Security Group

resource "aws_security_group" "app_sg" {
  name        = "app-tier-sg"
  description = "Allow traffic from web tier"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-tier-security-group"
  }
}

# RDS Instance Setup
resource "aws_db_instance" "app_db" {
  identifier             = "node-app-db"
  engine                 = "mysql"               # or "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
 // name                   = "nodeappdb"
  username               = "admin"
  password               = "StrongPassword123!"  # Consider using SSM parameter store for secrets
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Name = "node-app-db-instance"
  }
}

# Launch Template for App tier
locals {
  raw_data = <<-EOF
        #!/bin/bash
        sudo apt update -y
        sudo apt install -y curl gnupg
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
        mkdir -p /home/ubuntu/app
        echo "const http = require('http');" >> /home/ubuntu/app/server.js
        echo "const port = 3000;" >> /home/ubuntu/app/server.js
        echo "http.createServer((req, res) => res.end('Hello from Node.js!')).listen(port);" >> /home/ubuntu/app/server.js
        node /home/ubuntu/app/server.js &
        EOF
      encoded_script = base64encode(local.raw_data)
}

resource "aws_launch_template" "app_lt" {
  name_prefix   = "node-app-lt-"
  image_id      = "ami-01f23391a59163da9" # Replace with dynamic data source later
  instance_type = "t2.micro"
  key_name      = "obioma-key"
  vpc_security_group_ids = [aws_security_group.app_sg.id]

   user_data = local.encoded_script
}

# Target Group + Internal Load balancer
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.web_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "3000"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 5
  }
}

resource "aws_lb" "app_alb" {
  name               = "app-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [
    aws_subnet.private_subnet_a.id,
    aws_subnet.private_subnet_b.id
  ]
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Auto Scaling group
resource "aws_autoscaling_group" "app_asg" {
  name                      = "node-app-asg"
  desired_capacity          = 2
  max_size                  = 3
  min_size                  = 1
  vpc_zone_identifier       = [
    aws_subnet.private_subnet_a.id,
    aws_subnet.private_subnet_b.id
  ]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  health_check_type         = "EC2"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "NodeAppInstance"
    propagate_at_launch = true
  }
}



# Create CloudWatch Metric Alarms for Auto Scaling

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "high-cpu-app"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale up when CPU > 70%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  scaling_adjustment     = 1
  cooldown               = 300
}

