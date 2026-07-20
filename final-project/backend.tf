terraform {
  backend "s3" {
    bucket         = "final-project-tfstate-001001"
    key            = "final-project/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "final-project-tf-locks"
    encrypt        = true
  }
}

