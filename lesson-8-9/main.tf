locals {
  cluster_name = "lesson-8-9-eks"
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
  repository_name      = "lesson-8-9-django"
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
    Environment = "lesson-8-9"
    Project     = "django-app"
  }
}

module "jenkins" {
  source = "./modules/jenkins"

  cluster_name       = module.eks.cluster_name
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
  ecr_repository_arn = module.ecr.repository_arn

  admin_user      = "admin"
  admin_password  = "admin123"
  job_repo_url    = "https://github.com/roman-zubach/devops-hw.git"
  job_repo_branch = "main"

  tags = {
    Environment = "lesson-8-9"
    Project     = "django-app"
  }

  depends_on = [module.eks]
}

module "rds" {
  source = "./modules/rds"

  name       = "lesson-8-9"
  use_aurora = false

  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t3.micro"
  multi_az       = false

  db_name  = "appdb"
  username = "dbadmin"
  password = var.db_password
  port     = 5432

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  allowed_cidr_blocks        = ["10.0.0.0/16"]
  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  db_parameter_group_family = "postgres16"

  tags = {
    Environment = "lesson-8-9"
    Project     = "django-app"
  }
}

module "argo_cd" {
  source = "./modules/argo_cd"

  repo_url             = "https://github.com/roman-zubach/devops-hw.git"
  repo_target_revision = "main"
  chart_path           = "lesson-8-9/charts/django-app"
  image_repository     = module.ecr.repository_url

  depends_on = [module.eks]
}
