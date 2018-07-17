# Read in global variables
module "global_variables" {
  source = "../modules/global_variables"
}

data "aws_availability_zones" "available" {}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"

  tags {
    Name   = "Task Scheduler"
    Source = "Terraform Task Scheduler"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name   = "Task Scheduler"
    Source = "Terraform Task Scheduler"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "primary" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true

  tags {
    Name   = "Task Scheduler"
    Source = "Terraform Task Scheduler"
  }
}

resource "aws_subnet" "secondary" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = true

  tags {
    Name   = "Task Scheduler"
    Source = "Terraform Task Scheduler"
  }
}
