terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.67.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}
