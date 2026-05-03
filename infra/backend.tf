terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }

    backend "s3" {
        bucket = "terraform-analyzer-tfstate-kj"
        key = "terraform-analyzer/terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "terraform-analyzer-tflock"
        encrypt = true
    }
}

