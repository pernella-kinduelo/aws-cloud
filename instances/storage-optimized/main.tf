# ============================================================
#  TERRAFORM — Storage Optimized EC2 Instance
#  LearnUp Platform — Real-Time Log Analytics
# ============================================================
#
#  This file describes the storage infrastructure for
#  LearnUp's real-time event log analytics service.
#
#  Key architect decisions in this file:
#  1. i4i.xlarge -> local NVMe SSD, 10x faster than EBS
#  2. Automated S3 backup every 15 minutes -> data safety
#  3. Private subnet -> no direct internet access needed
#  4. Elasticsearch installed -> fast log querying
#
#  WARNING: Local NVMe storage is ephemeral.
#  Data is lost if the instance stops.
#  The S3 backup strategy below protects against data loss.
#
# ============================================================


# -------------------------------------------------------------
# BLOCK 1 : TERRAFORM CONFIGURATION
# -------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"  # Paris — GDPR compliance
}


# -------------------------------------------------------------
# BLOCK 2 : VARIABLES
# -------------------------------------------------------------

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
  Storage Optimized EC2 instance type.

  The "I" family = IOPS — ultra-fast local NVMe SSD storage.
  Use when your app reads/writes massive amounts of data
  and needs the absolute lowest latency possible.

  Available options:
  - i4i.xlarge  :  4 vCPU, 16 GB RAM,  1x 937 GB NVMe   (~$0.40/hour)  <- we start here
  - i4i.2xlarge :  8 vCPU, 32 GB RAM,  2x 937 GB NVMe   (~$0.80/hour)  <- growing volume
  - i4i.4xlarge : 16 vCPU, 64 GB RAM,  4x 937 GB NVMe   (~$1.60/hour)  <- large scale
  - i4i.8xlarge : 32 vCPU, 128 GB RAM, 8x 937 GB NVMe   (~$3.20/hour)  <- very large scale

  Key difference vs standard instances:
  -> Standard EBS disk : ~1ms latency, 64,000 IOPS max
  -> i4i NVMe local    : ~100 microseconds, 1,000,000+ IOPS

  Architect decision: i4i.xlarge for LearnUp's 10M daily events.
  Monitor IOPS with CloudWatch. Scale up if disk usage > 80%.
  EOT
  type        = string
  default     = "i4i.xlarge"
}


# -------------------------------------------------------------
# BLOCK 3 : NETWORK — VPC
# -------------------------------------------------------------

resource "aws_vpc" "learnup_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project}-vpc"
    Project     = var.project
    Environment = var.environment
  }
}


# -------------------------------------------------------------
# BLOCK 4 : PRIVATE SUBNET
# The analytics service does not need to be publicly accessible.
# It receives events from the web server and sends results
# to the dashboard (memory optimized instance).
#
# Subnet map for this project:
# 10.0.1.0/24 = public  (web server - t3.medium)
# 10.0.2.0/24 = private (AI correction - c6i.large)
# 10.0.3.0/24 = private (cache - r6i.large)
# 10.0.4.0/24 = private (GPU training - g5.xlarge)
# 10.0.5.0/24 = private (log analytics - i4i.xlarge) <- this one
# -------------------------------------------------------------

resource "aws_subnet" "learnup_subnet_storage" {
  vpc_id                  = aws_vpc.learnup_vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = false  # Private — no public IP

  tags = {
    Name    = "${var.project}-subnet-storage"
    Project = var.project
    Type    = "private"
  }
}


# -------------------------------------------------------------
# BLOCK 5 : SECURITY GROUP (Firewall)
# This instance needs to:
# 1. Receive events from the web server (port 9200 Elasticsearch)
# 2. Send analytics results to the dashboard instance
# 3. Write backups to S3 (outbound only)
# -------------------------------------------------------------

resource "aws_security_group" "learnup_storage_sg" {
  name        = "${var.project}-storage-sg"
  description = "Security rules for the storage optimized analytics instance"
  vpc_id      = aws_vpc.learnup_vpc.id

  # Allow Elasticsearch traffic from web server only
  # Elasticsearch runs on port 9200 by default
  ingress {
    description = "Elasticsearch from web server only"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]  # Web server subnet only
  }

  # Allow Elasticsearch cluster communication (port 9300)
  # Used if we scale to multiple Elasticsearch nodes later
  ingress {
    description = "Elasticsearch cluster communication"
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Internal VPC only
  }

  # SSH from internal network only
  ingress {
    description = "SSH from internal network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # All outbound traffic allowed
  # Needed to send backups to S3
  egress {
    description = "All outbound traffic allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-storage-sg"
    Project     = var.project
    Environment = var.environment
  }
}


# -------------------------------------------------------------
# BLOCK 6 : S3 BUCKET — Log Backup Storage
#
# CRITICAL ARCHITECT DECISION:
# Local NVMe data is lost if the instance stops.
# We back up all logs to S3 every 15 minutes.
# S3 is durable (99.999999999% — 11 nines) and cheap.
# This is the safety net for our ephemeral NVMe storage.
# -------------------------------------------------------------

resource "aws_s3_bucket" "learnup_logs" {
  bucket = "${var.project}-logs-backup-storage"

  tags = {
    Name        = "${var.project}-logs-backup"
    Project     = var.project
    Environment = var.environment
    Purpose     = "Backup of NVMe logs — protects against instance stop data loss"
  }
}

# Lifecycle rule: automatically move old logs to cheaper storage
resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.learnup_logs.id

  rule {
    id     = "logs-archiving"
    status = "Enabled"

    transition {
      days          = 30
      # After 30 days move to Glacier — much cheaper storage
      storage_class = "GLACIER"
    }

    expiration {
      # Delete logs after 1 year — GDPR compliance
      days = 365
    }
  }
}

# Encrypt all log files at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.learnup_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# -------------------------------------------------------------
# BLOCK 7 : THE EC2 INSTANCE — Storage Optimized
# i4i.xlarge with local NVMe SSD for real-time log analytics
# -------------------------------------------------------------

resource "aws_instance" "learnup_analytics" {

  ami           = "ami-0f15d55736fd476da"  # Amazon Linux 2023 - Paris
  instance_type = var.instance_type        # i4i.xlarge (storage optimized)

  subnet_id              = aws_subnet.learnup_subnet_storage.id
  vpc_security_group_ids = [aws_security_group.learnup_storage_sg.id]

  # Root disk — standard EBS for the operating system
  # The real performance comes from the LOCAL NVMe disk
  # which is automatically attached on i4i instances
  root_block_device {
    volume_size           = 50    # 50 GB for OS and application
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # Note: The i4i.xlarge automatically comes with
  # 1x 937 GB NVMe SSD locally attached.
  # This local disk appears as /dev/nvme1n1 on the instance.
  # It does NOT appear here in Terraform — it is hardware,
  # not a resource we create. We just mount and use it below.

  user_data = <<-EOF
    #!/bin/bash

    # System update
    yum update -y

    # -----------------------------------------------------
    # STEP 1: Mount the local NVMe drive
    # The NVMe disk is physically attached but needs
    # to be formatted and mounted before use
    # -----------------------------------------------------

    # Format the NVMe disk with XFS filesystem
    # XFS is optimized for large files and high throughput
    mkfs.xfs /dev/nvme1n1

    # Create mount point and mount the disk
    mkdir -p /data/nvme
    mount /dev/nvme1n1 /data/nvme

    # Auto-mount on reboot
    echo "/dev/nvme1n1 /data/nvme xfs defaults 0 0" >> /etc/fstab

    # Create directories for logs and analytics data
    mkdir -p /data/nvme/logs
    mkdir -p /data/nvme/elasticsearch

    # -----------------------------------------------------
    # STEP 2: Install Elasticsearch
    # Elasticsearch is a search engine built for fast
    # querying of large log datasets
    # -----------------------------------------------------

    rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
    yum install -y elasticsearch

    # Point Elasticsearch data to our fast NVMe drive
    sed -i 's|path.data:.*|path.data: /data/nvme/elasticsearch|' \
      /etc/elasticsearch/elasticsearch.yml

    systemctl start elasticsearch
    systemctl enable elasticsearch

    # -----------------------------------------------------
    # STEP 3: Set up automatic S3 backup every 15 minutes
    # This is the safety net for our ephemeral NVMe data
    # -----------------------------------------------------

    yum install -y awscli

    # Create backup script
    cat > /home/ec2-user/backup-to-s3.sh << 'BACKUPEOF'
    #!/bin/bash
    TIMESTAMP=$(date +%Y-%m-%d-%H-%M)
    BUCKET="${var.project}-logs-backup-storage"

    echo "[$TIMESTAMP] Starting S3 backup..."
    aws s3 sync /data/nvme/logs s3://$BUCKET/logs/$TIMESTAMP/
    echo "[$TIMESTAMP] Backup complete."
    BACKUPEOF

    chmod +x /home/ec2-user/backup-to-s3.sh

    # Schedule backup every 15 minutes with cron
    echo "*/15 * * * * ec2-user /home/ec2-user/backup-to-s3.sh" \
      >> /etc/crontab

    echo "Storage Optimized instance ready"
    echo "NVMe disk mounted at /data/nvme"
    echo "Elasticsearch running"
    echo "S3 backup scheduled every 15 minutes"
  EOF

  tags = {
    Name         = "${var.project}-analytics-server"
    Project      = var.project
    Environment  = var.environment
    InstanceType = "Storage Optimized - i4i.xlarge"
    Role         = "Real-time log analytics and event processing"
    Storage      = "937 GB local NVMe SSD — 1,000,000+ IOPS"
    BackupPolicy = "S3 backup every 15 minutes — max 15min data loss"
    WhyThisType  = "10M daily events require ultra-fast local disk — EBS too slow"
  }
}


# -------------------------------------------------------------
# BLOCK 8 : OUTPUTS
# -------------------------------------------------------------

output "private_ip" {
  description = "Private IP of the analytics instance (internal use only)"
  value       = aws_instance.learnup_analytics.private_ip
}

output "instance_id" {
  description = "EC2 instance ID (useful in AWS Console)"
  value       = aws_instance.learnup_analytics.id
}

output "nvme_storage" {
  description = "Local NVMe storage available on this instance"
  value       = "937 GB NVMe SSD at /data/nvme — 1,000,000+ IOPS, ~100 microsecond latency"
}

output "backup_bucket" {
  description = "S3 bucket used for automatic log backups"
  value       = aws_s3_bucket.learnup_logs.bucket
}

output "instance_type_deployed" {
  description = "Confirmation of the storage optimized instance deployed"
  value       = "Instance ${aws_instance.learnup_analytics.instance_type} (Storage Optimized) deployed in ${var.environment}"
}

output "architect_note" {
  description = "Why this instance type was chosen"
  value       = "i4i.xlarge chosen for ultra-fast local NVMe storage. 10x lower latency than EBS. Processes 10M daily events in near real-time. NVMe data backed up to S3 every 15 minutes for safety."
}


# ============================================================
#  HOW TO USE THIS FILE
#
#  1. terraform init     -> Downloads required plugins
#  2. terraform plan     -> Previews what will be created
#  3. terraform apply    -> Creates the infrastructure
#  4. terraform destroy  -> Deletes everything
#
#  Key differences from previous instances:
#  -> i4i.xlarge with local NVMe SSD (not just EBS)
#  -> NVMe disk mounted and formatted in user_data
#  -> Elasticsearch installed for fast log querying
#  -> S3 backup every 15 minutes (ephemeral data protection)
#  -> S3 lifecycle rule: Glacier after 30 days, delete after 1 year
#  -> Two S3 buckets total in this project (models + logs)
# ============================================================
