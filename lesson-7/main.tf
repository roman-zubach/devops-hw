locals {
  cluster_name = "lesson-7-eks"
}

module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "terraform-state-bucket-001001"
  table_name  = "terraform-locks"
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "vpc"
  cluster_name       = local.cluster_name
}

module "ecr" {
  source               = "./modules/ecr"
  repository_name      = "lesson-7-django"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  private_subnet_ids = module.vpc.private_subnets

  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 2
  node_max_size       = 4

  tags = {
    Environment = "lesson-7"
    Project     = "django-app"
  }
}
