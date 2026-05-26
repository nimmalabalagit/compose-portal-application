# infrastructure/backend.tf
#
# INTERVIEW TALKING POINT: Remote state is non-negotiable in team environments.
# S3 + DynamoDB gives you:
#   - Encrypted state at rest (SSE-S3 or SSE-KMS)
#   - Concurrent-access locking via DynamoDB conditional writes
#   - Full state history via S3 versioning (rollback any destroy)
#
# The bucket and DynamoDB table are bootstrapped once via:
#   aws s3 mb s3://estateflowai-terraform-state-371056712467
#   aws s3api put-bucket-versioning --bucket estateflowai-terraform-state-371056712467 \
#       --versioning-configuration Status=Enabled
#   aws dynamodb create-table \
#       --table-name estateflowai-terraform-locks \
#       --attribute-definitions AttributeName=LockID,AttributeType=S \
#       --key-schema AttributeName=LockID,KeyType=HASH \
#       --billing-mode PAY_PER_REQUEST
#
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }

  backend "s3" {
    bucket         = "estateflowai-terraform-state-371056712467"
    key            = "compose-portal/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "estateflowai-terraform-locks"
    # State isolation: each environment uses a different key path
    # dev:  compose-portal/dev/terraform.tfstate
    # prod: compose-portal/prod/terraform.tfstate
    # Override via: terraform init -backend-config="key=compose-portal/dev/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "EstateFlow-AI"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "nbalakrishna"
      CostCenter  = "platform-engineering"
    }
  }
}

# Kubernetes provider: uses EKS cluster data after cluster module creates it
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_name
}