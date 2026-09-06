terraform {
  backend "s3" {
    bucket         = "terraform-state-730335192690"
    key            = "terraform-project/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
