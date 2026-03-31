terraform {
  backend "s3" {
    bucket = "acme-terraform-state"
    key    = "production/terraform.tfstate"
    region = "us-east-2"
  }
}
