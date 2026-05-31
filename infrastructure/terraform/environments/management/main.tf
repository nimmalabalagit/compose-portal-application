# Management account root module
# Run: terraform apply -target=module.organizations first
# Then: terraform apply

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
  backend "s3" {
    bucket         = "estateflowai-terraform-state-371056712467"
    key            = "management/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "estateflowai-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "management"
  default_tags {
    tags = {
      Project     = "EstateFlow-AI"
      ManagedBy   = "Terraform"
      Environment = "management"
      Owner       = "nbalakrishna"
    }
  }
}
provider "aws" {
  region = var.aws_region
  alias  = "security"
  assume_role {
    role_arn = "arn:aws:iam::${module.organizations.security_account_id}:role/OrganizationAccountAccessRole"
  }
  default_tags {
    tags = {
      Project     = "EstateFlow-AI"
      ManagedBy   = "Terraform"
      Environment = "security"
    }
  }
}

data "aws_caller_identity" "management" { provider = aws.management }

module "organizations" {
  source                 = "../../modules/organizations"
  project_name           = var.project_name
  security_account_email = var.security_account_email
  dev_account_email      = var.dev_account_email
  staging_account_email  = var.staging_account_email
  prod_account_email     = var.prod_account_email
}

module "scp" {
  source           = "../../modules/scp"
  project_name     = var.project_name
  root_id          = module.organizations.root_id
  prod_ou_id       = module.organizations.prod_ou_id
  staging_ou_id    = module.organizations.staging_ou_id
  dev_ou_id        = module.organizations.dev_ou_id
  approved_regions = var.approved_regions
  depends_on       = [module.organizations]
}

module "security_account" {
  source                = "../../modules/security-account"
  project_name          = var.project_name
  aws_region            = var.aws_region
  security_account_id   = module.organizations.security_account_id
  management_account_id = data.aws_caller_identity.management.account_id
  depends_on            = [module.organizations, module.scp]
}
