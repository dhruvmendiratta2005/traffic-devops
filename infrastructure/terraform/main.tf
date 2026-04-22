terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- VPC & Network ---
resource "aws_vpc" "traffic_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "traffic-vpc"
  }
}

resource "aws_internet_gateway" "traffic_igw" {
  vpc_id = aws_vpc.traffic_vpc.id
  tags = {
    Name = "traffic-igw"
  }
}

resource "aws_subnet" "traffic_subnet" {
  vpc_id                  = aws_vpc.traffic_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = {
    Name = "traffic-subnet"
  }
}

resource "aws_route_table" "traffic_rt" {
  vpc_id = aws_vpc.traffic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.traffic_igw.id
  }
  tags = {
    Name = "traffic-rt"
  }
}

resource "aws_route_table_association" "traffic_rta" {
  subnet_id      = aws_subnet.traffic_subnet.id
  route_table_id = aws_route_table.traffic_rt.id
}

# --- Security Groups ---
resource "aws_security_group" "traffic_sg" {
  name        = "traffic_security_group"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.traffic_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In a real scenario, lock this to your IP
  }

  ingress {
    description = "HTTP (Dashboard)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Traffic API"
    from_port   = 5000
    to_port     = 5000
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
    Name = "traffic-sg"
  }
}

# --- SSH Key Pair Generation ---
resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "traffic_key" {
  key_name   = "traffic-key"
  public_key = tls_private_key.rsa_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.rsa_key.private_key_pem
  filename        = "${path.module}/../ansible/traffic-key.pem"
  file_permission = "0400"
}

# --- EC2 Instance ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "traffic_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro" # AWS Free Tier Eligible
  key_name      = aws_key_pair.traffic_key.key_name
  subnet_id     = aws_subnet.traffic_subnet.id
  vpc_security_group_ids = [aws_security_group.traffic_sg.id]

  tags = {
    Name = "Traffic-Simulation-Server"
  }
}
