# ============================================================
#  TERRAFORM — Compute Optimized EC2 Instance
#  LearnUp Platform — AI Exam Correction Service
# ============================================================
#
#  This file describes the dedicated compute infrastructure
#  for LearnUp's AI-powered exam correction feature.
#
#  Why a separate instance?
#  → Correcting 500 exams simultaneously requires intense CPU power.
#  → Instead of overloading the general purpose instance (and slowing
#    down the website for everyone), we isolate this workload here.
#
#  This is called "Separation of Concerns" — a key principle
#  for any Cloud Architect.
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
  Compute Optimized EC2 instance type.

  The "C" family = Compute — high-performance CPU, less RAM.
  Use when CPU is the bottleneck, not memory.

  Available options by workload:
  - c6i.large   : 2 vCPU, 4 GB RAM  (~$75/month)  <- we start here
  - c6i.xlarge  : 4 vCPU, 8 GB RAM  (~$150/month) <- if exam volume grows
  - c6i.2xlarge : 8 vCPU, 16 GB RAM (~$300/month) <- high traffic periods
  - c7g.large   : ARM Graviton, better price/perf  (~$60/month)
  EOT
  type        = string
  default     = "c6i.large"
}


# ─────────────────────────────────────────────────────────────
# BLOCK 3 : NETWORK — VPC
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
# Unlike the general purpose instance (public subnet),
# the compute instance is in a PRIVATE subnet.
#
# Why private?
# → The AI correction service does NOT need to be
#   directly accessible from the internet.
# → Only the web server can send it exam correction jobs.
# → Private = more secure, less attack surface.
# ─────────────────────────────────────────────────────────────

resource "aws_subnet" "learnup_subnet_private" {
  vpc_id                  = aws_vpc.learnup_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.project}-subnet-private"
    Project = var.project
    Type    = "private"
  }
}


# ─────────────────────────────────────────────────────────────
# BLOCK 5 : SECURITY GROUP (Firewall)
# Much stricter than the general purpose instance:
# → No direct internet access
# → Only the web server subnet can send traffic here
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "learnup_compute_sg" {
  name        = "${var.project}-compute-sg"
  description = "Security rules for the AI correction compute instance"
  vpc_id      = aws_vpc.learnup_vpc.id

  # Allow internal traffic from web server only (port 8080)
  ingress {
    description = "Internal traffic from web server only"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]  # Only the web server subnet
  }

  # SSH from internal network only — no direct access from internet
  ingress {
    description = "SSH from internal network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Only from within our VPC
  }

  # All outbound traffic allowed
  egress {
    description = "All outbound traffic allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-compute-sg"
    Project     = var.project
    Environment = var.environment
  }
}


# ─────────────────────────────────────────────────────────────
# BLOCK 6 : THE EC2 INSTANCE — Compute Optimized
# c6i.large dedicated to AI exam correction
# ─────────────────────────────────────────────────────────────

resource "aws_instance" "learnup_ai_correction" {
  ami           = "ami-0f15d55736fd476da"  # Amazon Linux 2023 - Paris
  instance_type = var.instance_type        # c6i.large (compute optimized)

  # Private subnet — not directly reachable from internet
  subnet_id              = aws_subnet.learnup_subnet_private.id
  vpc_security_group_ids = [aws_security_group.learnup_compute_sg.id]

  root_block_device {
    volume_size           = 30    # 30 GB — enough for OS + AI models
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Startup script: installs Python and AI correction dependencies
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-pip
    pip3 install flask
    pip3 install scikit-learn
    pip3 install numpy
    echo "Compute Optimized instance ready for AI exam correction"
  EOF

  tags = {
    Name         = "${var.project}-ai-correction-server"
    Project      = var.project
    Environment  = var.environment
    InstanceType = "Compute Optimized - c6i.large"
    Role         = "AI exam correction service"
    WhyThisType  = "CPU-intensive workload: AI correction of 500+ simultaneous exams"
  }
}


# ─────────────────────────────────────────────────────────────
# BLOCK 7 : OUTPUTS
# No public IP here — this instance is private by design
# ─────────────────────────────────────────────────────────────

output "private_ip" {
  description = "Private IP of the AI correction instance (internal use only)"
  value       = aws_instance.learnup_ai_correction.private_ip
}

output "instance_id" {
  description = "EC2 instance ID (useful in AWS Console)"
  value       = aws_instance.learnup_ai_correction.id
}

output "instance_type_deployed" {
  description = "Confirmation of the compute optimized instance deployed"
  value       = "Instance ${aws_instance.learnup_ai_correction.instance_type} (Compute Optimized) deployed in ${var.environment}"
}

output "architect_note" {
  description = "Why this instance type was chosen"
  value       = "c6i.large chosen for CPU-intensive AI workload. Isolated in private subnet for security. Web server communicates internally via port 8080."
}


# ============================================================
#  HOW TO USE THIS FILE
#
#  1. terraform init      -> Downloads required plugins
#  2. terraform plan      -> Previews what will be created
#  3. terraform apply     -> Actually creates the infrastructure
#  4. terraform destroy   -> Deletes everything (avoids extra costs)
#
#  Key differences from general-purpose/main.tf:
#  -> Private subnet (no public IP)
#  -> Stricter security group (internal traffic only)
#  -> c6i.large instead of t3.medium (more CPU power)
#  -> Python + AI libraries instead of Nginx
# ============================================================
