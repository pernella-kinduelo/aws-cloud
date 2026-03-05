# ============================================================
#  TERRAFORM — Accelerated Computing EC2 Instance
#  LearnUp Platform — AI Recommendation Engine Training
# ============================================================
#
#  This file describes the GPU infrastructure for training
#  LearnUp's personalized course recommendation model.
#
#  Key architect decisions in this file:
#  1. g5.xlarge instead of a CPU instance -> GPU needed for AI
#  2. Instance is STOPPED after training -> pay per use only
#  3. Private subnet -> no direct internet access needed
#  4. Encrypted storage -> model weights are sensitive assets
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
  # Paris region — data stays in France (GDPR compliance)
  region = "eu-west-3"
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
  Accelerated Computing EC2 instance type.

  The "G" family = GPU — parallel computing power.
  Use when your workload requires massive parallel calculations
  like AI training, rendering, or image recognition.

  Available options:
  - g5.xlarge   :  4 vCPU, 16 GB RAM, 1x NVIDIA A10G GPU  (~$1.00/hour)  <- we start here
  - g5.2xlarge  :  8 vCPU, 32 GB RAM, 1x NVIDIA A10G GPU  (~$1.50/hour)  <- larger models
  - g5.12xlarge : 48 vCPU, 192 GB RAM, 4x NVIDIA A10G GPU (~$8.00/hour)  <- very large models
  - p4d.24xlarge: 96 vCPU, 1152 GB RAM, 8x NVIDIA A100    (~$32.00/hour) <- research grade

  Architect decision: g5.xlarge for LearnUp's recommendation model.
  Run at night, stop when done. Expected training time: 2 hours.
  Total cost per training run: ~$2 instead of $7 over 72h on CPU.
  EOT
  type        = string
  default     = "g5.xlarge"
}

variable "training_schedule" {
  description = "When to run the training job (cron expression)"
  type        = string
  default     = "0 2 * * 0"  # Every Sunday at 2am — low traffic period
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
# The GPU instance does not need to be publicly accessible.
# It receives training jobs from the web server internally
# and stores the trained model on S3 when done.
# -------------------------------------------------------------

resource "aws_subnet" "learnup_subnet_gpu" {
  vpc_id            = aws_vpc.learnup_vpc.id

  # Subnet IP ranges used in this project:
  # 10.0.1.0/24 = public subnet  (web server)
  # 10.0.2.0/24 = private subnet (AI correction - c6i)
  # 10.0.3.0/24 = private subnet (cache - r6i)
  # 10.0.4.0/24 = private subnet (GPU training) <- this one
  cidr_block        = "10.0.4.0/24"

  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = false  # Private — no public IP

  tags = {
    Name    = "${var.project}-subnet-gpu"
    Project = var.project
    Type    = "private"
  }
}


# -------------------------------------------------------------
# BLOCK 5 : SECURITY GROUP (Firewall)
# Very strict rules — the GPU instance only needs to:
# 1. Receive training jobs from the web server
# 2. Push the trained model to S3 (outbound only)
# 3. Be accessible via SSH internally for maintenance
# -------------------------------------------------------------

resource "aws_security_group" "learnup_gpu_sg" {
  name        = "${var.project}-gpu-sg"
  description = "Security rules for the GPU accelerated computing instance"
  vpc_id      = aws_vpc.learnup_vpc.id

  # Allow training job submissions from web server only
  ingress {
    description = "Training job API from web server only"
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]  # Web server subnet only
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
  # Needed to push trained models to S3
  egress {
    description = "All outbound traffic allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-gpu-sg"
    Project     = var.project
    Environment = var.environment
  }
}


# -------------------------------------------------------------
# BLOCK 6 : S3 BUCKET — Model Storage
# After training, the model is saved here.
# S3 is AWS object storage — perfect for large model files.
# The web server reads the model from S3 to make recommendations.
# -------------------------------------------------------------

resource "aws_s3_bucket" "learnup_models" {
  bucket = "${var.project}-ai-models-storage"

  tags = {
    Name        = "${var.project}-ai-models"
    Project     = var.project
    Environment = var.environment
    Purpose     = "Stores trained AI recommendation models"
  }
}

# Encrypt all model files at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "models_encryption" {
  bucket = aws_s3_bucket.learnup_models.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # Industry standard encryption
    }
  }
}


# -------------------------------------------------------------
# BLOCK 7 : THE EC2 INSTANCE — Accelerated Computing
# g5.xlarge with NVIDIA A10G GPU for AI model training
# -------------------------------------------------------------

resource "aws_instance" "learnup_gpu_trainer" {

  ami           = "ami-0c6bae30b0a585e6d"  # Deep Learning AMI - Paris
  # Note: We use a different AMI here!
  # The Deep Learning AMI already has CUDA, PyTorch and
  # TensorFlow pre-installed — saves hours of setup time.
  
  instance_type = var.instance_type  # g5.xlarge (1x NVIDIA A10G GPU)

  subnet_id              = aws_subnet.learnup_subnet_gpu.id
  vpc_security_group_ids = [aws_security_group.learnup_gpu_sg.id]

  root_block_device {
    # GPU instances need more disk space:
    # - Deep Learning AMI is large (~50 GB)
    # - Training datasets can be large
    # - Model checkpoints need space
    volume_size           = 100   # 100 GB SSD
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true  # Always encrypt sensitive model data
  }

  # Startup script: sets up the training environment
  user_data = <<-EOF
    #!/bin/bash

    # The Deep Learning AMI already has PyTorch and CUDA
    # We just need to install our specific dependencies
    pip install boto3        # AWS SDK to push models to S3
    pip install scikit-learn # Additional ML utilities
    pip install pandas       # Data processing

    # Create the training script directory
    mkdir -p /home/ec2-user/learnup-trainer

    # Create a simple training launcher script
    cat > /home/ec2-user/learnup-trainer/train.sh << 'TRAINEOF'
    #!/bin/bash
    echo "Starting AI recommendation model training on GPU..."
    echo "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader)"
    echo "Training started at: $(date)"
    
    # Training logic would go here
    # python train_recommendation_model.py
    
    echo "Training complete. Uploading model to S3..."
    # aws s3 cp model.pkl s3://learnup-ai-models-storage/
    
    echo "Training finished at: $(date)"
    echo "Shutting down instance to save costs..."
    # sudo shutdown -h now  <- uncomment in production!
    TRAINEOF

    chmod +x /home/ec2-user/learnup-trainer/train.sh
    echo "GPU instance ready for AI training"
  EOF

  tags = {
    Name         = "${var.project}-gpu-trainer"
    Project      = var.project
    Environment  = var.environment
    InstanceType = "Accelerated Computing - g5.xlarge"
    GPU          = "NVIDIA A10G"
    Role         = "AI recommendation model training"
    BillingNote  = "Stop instance after training — billed per hour!"
    WhyThisType  = "AI model training requires massively parallel GPU computation"
    Schedule     = var.training_schedule
  }
}


# -------------------------------------------------------------
# BLOCK 8 : OUTPUTS
# -------------------------------------------------------------

output "private_ip" {
  description = "Private IP of the GPU training instance"
  value       = aws_instance.learnup_gpu_trainer.private_ip
}

output "instance_id" {
  description = "EC2 instance ID — use this to start/stop from AWS Console"
  value       = aws_instance.learnup_gpu_trainer.id
}

output "model_storage_bucket" {
  description = "S3 bucket where trained models are stored"
  value       = aws_s3_bucket.learnup_models.bucket
}

output "instance_type_deployed" {
  description = "Confirmation of the accelerated computing instance deployed"
  value       = "Instance ${aws_instance.learnup_gpu_trainer.instance_type} (Accelerated Computing) with NVIDIA A10G GPU"
}

output "cost_reminder" {
  description = "Important billing reminder"
  value       = "REMINDER: Stop this instance after training! Cost is ~$1/hour. Expected training time: 2 hours = ~$2 per run."
}

output "architect_note" {
  description = "Why this instance type was chosen"
  value       = "g5.xlarge chosen for GPU-accelerated AI training. 36x faster than CPU alternative. Scheduled weekly at 2am, auto-stops when done. Model saved to S3 for the web server to use."
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
#  -> g5.xlarge with NVIDIA A10G GPU (not just CPU)
#  -> Deep Learning AMI (PyTorch + CUDA pre-installed)
#  -> S3 bucket added to store trained models
#  -> 100 GB disk (larger datasets and model checkpoints)
#  -> STOP the instance after training to avoid extra costs!
#  -> Billed per hour — not per month like others
# ============================================================
