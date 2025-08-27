terraform {
  backend "local" {
    path = "aws-infra-master-terraform.tfstate"
  }
}
