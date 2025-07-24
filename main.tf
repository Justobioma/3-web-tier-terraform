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

# EC2 Instance for Web Tier Setup

resource "aws_instance" "web_server" {
  ami                    = "ami-01f23391a59163da9 (64-bit (x86))" # Replace with a dynamic AMI later
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
 // key_name               = "saa-lab1" # Replace with your actual key pair
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
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

# EC2 Instances for App Tier Setup

resource "aws_instance" "node_app" {
  ami                    = "ami-01f23391a59163da9 (64-bit (x86))" # Ubuntu or Amazon Linux
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  //key_name               = "obioma-key"
  associate_public_ip_address = false

  user_data = <<-EOF
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

  tags = {
    Name = "node-backend-server"
  }
}