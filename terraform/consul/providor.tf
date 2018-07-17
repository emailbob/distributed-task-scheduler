# Specify the provider and access details
provider "aws" {
  region = "${module.global_variables.aws_region}"
}
