terraform {
  backend "s3" {
    bucket  = "fila2-terraform-state-2026-project"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
