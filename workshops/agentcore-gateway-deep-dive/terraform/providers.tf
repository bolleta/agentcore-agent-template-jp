terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.47"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.85"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.9"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "awscc" {
  region = "ap-northeast-1"
}
