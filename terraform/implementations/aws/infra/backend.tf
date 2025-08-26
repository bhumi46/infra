terraform {
  backend "local" {
    path = "aws-infra-develop-terraform.tfstate"
  }
}
