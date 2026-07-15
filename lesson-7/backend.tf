terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-001001"
    key            = "lesson-7/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

