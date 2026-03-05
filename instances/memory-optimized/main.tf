# ============================================================
#  TERRAFORM — Memory Optimized EC2 Instance
#  LearnUp Platform — Real-Time Teacher Dashboard
# ============================================================
#
#  This file describes the dedicated memory infrastructure
#  for LearnUp's real-time statistics and caching layer.
#
#  Why a memory optimized instance?
#  → The dashboard reads student progress data thousands of
#    times per second.
#  → Keeping all this data in RAM (instead of disk) makes
#    responses instantaneous.
#  → RAM is 100x faster than even the fastest SSD.
#
#  Key architecture principle: each instance does what it
#  does best. The r6i.large handles memory-heavy workloads
#  so the web server stays fast for everyone.
#
# ============================================================


# ─────────────────────────────────────────────────────────────
# BLOCK 1 : TERRAFORM CONFIGURATION
# ─────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # Paris region — data stays in France (GDPR compliance)
  region = "eu-west-3"
}


# ─────────────────────────────────────────────────────────────
# BLOCK 2 : VARIABLES
# ─────────────────────────────────────────────────────────────

variable "project" {
  description = "Project name"
  type        = string
  default     = "learnup"
}

variable "environment" {
  description = "Environment: dev, staging or production"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = <<EOT
  Memory Optimized EC2 instance type.

  The "R" family = RAM — large memory, standard CPU.
  Use when your app reads large datasets repeatedly
  and needs instant access to data.

  Available options by workload:
  - r6i.large   :  2 vCPU, 16 GB RAM  (~$120/month) <- we start here
  - r6i.xlarge  :  4 vCPU, 32 GB RAM  (~$240/month) <- growing platform
  - r6i.2xlarge :  8 vCPU, 64 GB RAM  (~$480/month) <- large scale
  - r6g.large   :  2 vCPU, 16 GB RAM  (~$100/month) <- ARM, better price

  Key difference vs t3.medium:
  -> t3.medium = 4 GB RAM
  -> r6i.large = 16 GB RAM (4x more memory, same CPU count)

  Architect decision: start with r6i.large and monitor RAM usage
  with CloudWatch. If memory usage stays above 80% -> scale up.
  EOT
  type        = string
  default     = "r6i.large"
}


# ─────────────────────────────────────────────────────────────
# BLOCK 3 : NETWORK — VPC
# Same VPC as the other instances so they can communicate
# securely without going through the internet.
# ─────────────────────────────────────────────────────────────

resource "aws_vpc" "learnup_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project}-vpc"
    Project     = var.project
    Environment = var.environment
  }
}


# ─────────────────────────────────────────────────────────────
# BLOCK 4 : PRIVATE SUBNET
# The dashboard cache does NOT need to be directly accessible
# from the internet — only the web server talks to it.
# Private subnet = more secure, less attack surface.
# ─────────────────────────────────────────────────────────────

resource "aws_subnet" "learnup_subnet_memory" {
  vpc_id            = aws_vpc.learnup_vpc.id

  # Each subnet needs its own unique IP range:
  # 10.0.1.0/24 = public subnet (web server)
  # 10.0.2.0/24 = private subnet (AI correction)
  # 10.0.3.0/24 = private subnet (memory / cache) <- this one
  cidr_block        = "10.0.3.0/24"

  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = false  # Private — no public IP

  tags = {
    Name    = "${var.project}-subnet-memory"
    Project = var.project
    Type    = "private"
  }
}


# ─────────────────────────────────────────────────────────────
# BLOCK 5 : SECURITY GROUP (Firewall)
# This instance only needs to:
# 1. Receive read/write requests from the web server
# 2. Be accessible via SSH for maintenance (internal only)
# Everything else is blocked.
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "learnup_memory_sg" {
  name        = "${var.project}-memory-sg"
  description = "Security rules for the memory optimized cache instance"
  vpc_id      = aws_vpc.learnup_vpc.id

  # ── INBOUND TRAFFIC ──────────────────────────────────────

  # Rule 1: Allow Redis traffic from web server only
  # Redis (in-memory cache) runs on port 6379
  # Only the web server subnet (10.0.1.0/24) can connect
  ingress {
    description = "Redis cache traffic from web server only"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]  # Web server subnet only
  }

  # Rule 2: Allow dashboard API traffic from web server
  # The dashboard service runs on port 8081
  ingress {
    description = "Dashboard API from web server only"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  # Rule 3: SSH from internal network only
  ingress {
    description = "SSH from internal network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Only from within our VPC
  }

  # ── OUTBOUND TRAFFIC ─────────────────────────────────────

  egress {
    description = "All outbound traffic allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-memory-sg"
    Project     = var.project
    Environment = var.environment
  }
}


# ─────────────────────────────────────────────────────────────
# BLOCK 6 : THE EC2 INSTANCE — Memory Optimized
# r6i.large with 16 GB RAM for real-time dashboard and caching
# ─────────────────────────────────────────────────────────────

resource "aws_instance" "learnup_dashboard_cache" {

  ami           = "ami-0f15d55736fd476da"  # Amazon Linux 2023 - Paris
  instance_type = var.instance_type        # r6i.large (memory optimized)

  # Private subnet — not reachable directly from internet
  subnet_id              = aws_subnet.learnup_subnet_memory.id
  vpc_security_group_ids = [aws_security_group.learnup_memory_sg.id]

  # Storage — we need less disk because data lives in RAM
  # But we keep enough for the OS, logs and overflow
  root_block_device {
    volume_size           = 30    # 30 GB SSD
    volume_type           = "gp3"
    delete_on_termination = true

    # Important: encrypt the disk
    # Student data is sensitive — always encrypt at rest
    encrypted = true
  }

  # Startup script: installs Redis (in-memory cache)
  # and the dashboard statistics service
  user_data = <<-EOF
    #!/bin/bash

    # System update
    yum update -y

    # Install Redis — the most popular in-memory cache
    # Redis keeps data in RAM for ultra-fast access
    yum install -y redis

    # Configure Redis to use most of the available RAM
    # r6i.large has 16 GB — we allocate 12 GB to Redis
    echo "maxmemory 12gb" >> /etc/redis/redis.conf
    echo "maxmemory-policy allkeys-lru" >> /etc/redis/redis.conf

    # Start Redis
    systemctl start redis
    systemctl enable redis

    # Install Python for the dashboard statistics service
    yum install -y python3 python3-pip
    pip3 install flask redis pandas

    echo "Memory Optimized instance ready — Redis cache running with 12GB RAM"
  EOF

  tags = {
    Name         = "${var.project}-dashboard-cache"
    Project      = var.project
    Environment  = var.environment
    InstanceType = "Memory Optimized - r6i.large"
    Role         = "Real-time dashboard cache and statistics service"
    RAM          = "16 GB — 12 GB allocated to Redis cache"
    WhyThisType  = "Reads student progress data thousands of times per second — must stay in RAM"
  }
}


# ─────────────────────────────────────────────────────────────
# BLOCK 7 : OUTPUTS
# Private IP only — this instance has no public access
# ─────────────────────────────────────────────────────────────

output "private_ip" {
  description = "Private IP of the dashboard cache instance (internal use only)"
  value       = aws_instance.learnup_dashboard_cache.private_ip
}

output "instance_id" {
  description = "EC2 instance ID (useful in AWS Console)"
  value       = aws_instance.learnup_dashboard_cache.id
}

output "instance_type_deployed" {
  description = "Confirmation of the memory optimized instance deployed"
  value       = "Instance ${aws_instance.learnup_dashboard_cache.instance_type} (Memory Optimized) deployed in ${var.environment}"
}

output "ram_available" {
  description = "Total RAM available on this instance"
  value       = "16 GB RAM — r6i.large — 4x more memory than t3.medium (4 GB)"
}

output "architect_note" {
  description = "Why this instance type was chosen"
  value       = "r6i.large chosen for memory-heavy workload: real-time dashboard reads thousands of data points per second. Redis cache keeps all student data in RAM for instant access. Private subnet for security."
}


# ============================================================
#  HOW TO USE THIS FILE
#
#  1. terraform init      -> Downloads required plugins
#  2. terraform plan      -> Previews what will be created
#  3. terraform apply     -> Actually creates the infrastructure
#  4. terraform destroy   -> Deletes everything (avoids extra costs)
#
#  Key differences from the previous instances:
#  -> r6i.large instead of t3.medium or c6i.large (16 GB RAM!)
#  -> Redis installed (in-memory cache)
#  -> Disk encryption enabled (student data is sensitive)
#  -> Port 6379 open internally (Redis default port)
#  -> 12 GB of RAM allocated to Redis cache
# ============================================================
