terraform {
  backend "s3" {
    bucket         = "terraform-state-364931100987-project"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
