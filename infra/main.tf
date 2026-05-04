terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# IaC scan: public bucket / data exposure risk.
resource "aws_s3_bucket" "student_exports" {
  bucket = "campushub-student-exports-demo"
}

resource "aws_s3_bucket_public_access_block" "student_exports" {
  bucket = aws_s3_bucket.student_exports.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# IaC scan: wide-open ingress.
resource "aws_security_group" "campushub_api" {
  name        = "campushub-api-demo"
  description = "Intentionally vulnerable demo SG"

  ingress {
    description = "Open HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Open SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IaC/secrets demo: intentionally bad practice.
variable "database_password" {
  type    = string
  default = "UniversityDemoPassword123!"
}
