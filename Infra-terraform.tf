# Terraform version
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

#---------------------------#
# VPC and Networking
#---------------------------#
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24", "10.0.3.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  create_database_subnet_group = true

  tags = {
    Name = "eks-vpc"
  }
}

#---------------------------#
# IAM for EKS
#---------------------------#
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

module "eks_roles" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.30.0"

  name               = "eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ]
}

#---------------------------#
# EKS Cluster
#---------------------------#
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "MyEKSCluster"
  cluster_version = "1.29"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  manage_aws_auth = true

  enable_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 7

  eks_managed_node_groups = {
    default = {
      desired_size = 2
      max_size     = 4
      min_size     = 1

      instance_types = ["t3.medium"]

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

#---------------------------#
# RDS MySQL
#---------------------------#
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.4.0"

  identifier = "my-rds"
  engine     = "mysql"

  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  name                 = "mydatabase"
  username             = "dbadmin"
  password             = "MySecurePwd123!"

  multi_az = true

  vpc_security_group_ids = [module.eks.node_security_group_id]
  db_subnet_group_name   = module.vpc.database_subnet_group
  subnet_ids             = module.vpc.private_subnets

  tags = {
    Name = "my-rds"
  }
}

#---------------------------#
# Outputs
#---------------------------#
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
