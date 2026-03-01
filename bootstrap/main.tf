provider "aws" {
  region = "us-east-1"
}

# --- S3 BUCKET ---
resource "aws_s3_bucket" "backend_bucket" {
  bucket = "terraform-state-364931100987-project" 
  # Evita borrarlo por accidente
  lifecycle {
    prevent_destroy = true
  }
}

# Activar versionado (Por si se rompe el archivo, poder volver atrás)
resource "aws_s3_bucket_versioning" "backend_bucket" {
  bucket = aws_s3_bucket.backend_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado de datos (Seguridad básica)
resource "aws_s3_bucket_server_side_encryption_configuration" "backend_bucket" {
  bucket = aws_s3_bucket.backend_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Això assegura que el bucket sigui PRIVAT i ningú pugui obrir-lo a Internet.
resource "aws_s3_bucket_public_access_block" "backend_bucket" {
  bucket = aws_s3_bucket.backend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DYNAMODB TABLE ---
resource "aws_dynamodb_table" "backend_lock" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}