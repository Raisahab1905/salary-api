terraform {
  backend "s3" {
    bucket         = "rai1-terraform-state"
    key            = "salary-api/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
