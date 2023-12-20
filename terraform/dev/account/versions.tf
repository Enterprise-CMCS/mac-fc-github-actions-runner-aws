terraform {
  required_version = "= 1.5.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.30.0"
    }
  }
}

provider "aws" {
  allowed_account_ids = ["037370603820"]
}
