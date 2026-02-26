# ============================================================
#  TERRAFORM — Infrastructure LearnUp (Plateforme E-Learning)
#  Instance EC2 à Usage Général
# ============================================================
#
#  Ce fichier décrit l'infrastructure AWS de la plateforme
#  "LearnUp" en code. Terraform lit ce fichier et crée
#  automatiquement toutes les ressources sur AWS.
#
#  Pour une Cloud Architect, c'est ce qu'on appelle
#  l'"Infrastructure-as-Code" (IaC) : l'infra est versionnable,
#  reproductible et documentée comme du code.
#
# ============================================================


# ─────────────────────────────────────────────────────────────
# BLOC 1 : CONFIGURATION DE BASE
# Dit à Terraform qu'on utilise AWS et quelle région
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
  # On déploie dans la région Paris (eu-west-3)
  # Avantage : données hébergées en France (conformité RGPD)
  region = "eu-west-3"
}


# ─────────────────────────────────────────────────────────────
# BLOC 2 : VARIABLES
# Valeurs réutilisables dans tout le fichier
# ─────────────────────────────────────────────────────────────

variable "projet" {
  description = "Nom du projet"
  type        = string
  default     = "learnup"
}

variable "environnement" {
  description = "Environnement : dev, staging ou production"
  type        = string
  default     = "production"
}

variable "type_instance" {
  description = <<EOT
  Type d'instance EC2 à usage général.
  
  Choix possibles selon la charge :
  - t3.micro   : dev/test, ~500 Mo RAM  (~8$/mois)
  - t3.medium  : production légère, ~4 Go RAM  (~35$/mois)  ← on démarre ici
  - t3.large   : production croissante, ~8 Go RAM  (~65$/mois)
  - m6i.large  : production robuste, ~8 Go RAM optimisé  (~90$/mois)
  EOT
  type        = string
  default     = "t3.medium"
}


# ─────────────────────────────────────────────────────────────
# BLOC 3 : RÉSEAU — VPC (Virtual Private Cloud)
# Un VPC = notre réseau privé isolé dans AWS
# ─────────────────────────────────────────────────────────────

resource "aws_vpc" "learnup_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name          = "${var.projet}-vpc"
    Projet        = var.projet
    Environnement = var.environnement
  }
}


# ─────────────────────────────────────────────────────────────
# BLOC 4 : SOUS-RÉSEAU PUBLIC
# ─────────────────────────────────────────────────────────────

resource "aws_subnet" "learnup_subnet_public" {
  vpc_id                  = aws_vpc.learnup_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = true

  tags = {
    Name   = "${var.projet}-subnet-public"
    Projet = var.projet
  }
}


# ─────────────────────────────────────────────────────────────
# BLOC 5 : PASSERELLE INTERNET
# Permet au sous-réseau public de communiquer avec internet
# ─────────────────────────────────────────────────────────────

resource "aws_internet_gateway" "learnup_igw" {
  vpc_id = aws_vpc.learnup_vpc.id

  tags = {
    Name   = "${var.projet}-internet-gateway"
    Projet = var.projet
  }
}

resource "aws_route_table" "learnup_route_public" {
  vpc_id = aws_vpc.learnup_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.learnup_igw.id
  }

  tags = {
    Name   = "${var.projet}-route-table-public"
    Projet = var.projet
  }
}

resource "aws_route_table_association" "learnup_rta" {
  subnet_id      = aws_subnet.learnup_subnet_public.id
  route_table_id = aws_route_table.learnup_route_public.id
}


# ─────────────────────────────────────────────────────────────
# BLOC 6 : SECURITY GROUP (Pare-feu)
# Principe : tout bloquer par défaut, n'ouvrir que le nécessaire
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "learnup_sg" {
  name        = "${var.projet}-security-group"
  description = "Regles de securite pour l instance EC2 LearnUp"
  vpc_id      = aws_vpc.learnup_vpc.id

  # Autoriser HTTP (port 80)
  ingress {
    description = "HTTP depuis internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser HTTPS (port 443)
  ingress {
    description = "HTTPS depuis internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser SSH (port 22) pour l'administration
  ingress {
    description = "SSH pour administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ⚠️ En prod réelle : remplacer par l'IP de ton équipe
  }

  # Tout le trafic sortant autorisé
  egress {
    description = "Tout le trafic sortant autorise"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name          = "${var.projet}-sg"
    Projet        = var.projet
    Environnement = var.environnement
  }
}


# ─────────────────────────────────────────────────────────────
# BLOC 7 : L'INSTANCE EC2 — Le cœur du projet
# Instance à usage général t3.medium pour LearnUp
# ─────────────────────────────────────────────────────────────

resource "aws_instance" "learnup_serveur" {
  ami           = "ami-0f15d55736fd476da"  # Amazon Linux 2023 - Paris
  instance_type = var.type_instance        # t3.medium (usage général)

  subnet_id              = aws_subnet.learnup_subnet_public.id
  vpc_security_group_ids = [aws_security_group.learnup_sg.id]

  root_block_device {
    volume_size           = 20     # 20 Go SSD
    volume_type           = "gp3"  # SSD nouvelle génération
    delete_on_termination = true
  }

  # Script exécuté au 1er démarrage : installe Nginx
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>LearnUp est en ligne ! 🎓</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name          = "${var.projet}-serveur-web"
    Projet        = var.projet
    Environnement = var.environnement
    TypeInstance  = "Usage General - t3.medium"
    Role          = "Serveur web et API principale"
  }
}


# ─────────────────────────────────────────────────────────────
# BLOC 8 : OUTPUTS
# Affiche les infos importantes après le déploiement
# ─────────────────────────────────────────────────────────────

output "ip_publique_instance" {
  description = "Adresse IP publique de l instance LearnUp"
  value       = aws_instance.learnup_serveur.public_ip
}

output "dns_public_instance" {
  description = "URL pour acceder au site"
  value       = aws_instance.learnup_serveur.public_dns
}

output "id_instance" {
  description = "Identifiant unique de l instance EC2"
  value       = aws_instance.learnup_serveur.id
}

output "type_instance_deploye" {
  description = "Confirmation du type d instance deploye"
  value       = "Instance ${aws_instance.learnup_serveur.instance_type} (Usage General) deployee dans ${var.environnement}"
}


# ============================================================
#  COMMANDES TERRAFORM :
#
#  terraform init     → Télécharge les plugins
#  terraform plan     → Prévisualise les changements
#  terraform apply    → Crée l'infrastructure sur AWS
#  terraform destroy  → Supprime tout
# ============================================================
