terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "salary-api/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
