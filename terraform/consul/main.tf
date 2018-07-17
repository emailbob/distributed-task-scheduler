# Read in global variables
module "global_variables" {
  source = "../modules/global_variables"
}

# Get our VPC id filtered by tags
data "aws_vpc" "default" {
  tags {
    Name   = "Task Scheduler"
    Source = "Terraform Task Scheduler"
  }
}

# Get our subnet id
data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

# Set our subnet id
data "aws_subnet" "default" {
  count = "${length(data.aws_subnet_ids.default.ids)}"
  id    = "${data.aws_subnet_ids.default.ids[count.index]}"
}

# Provides an EC2 key pair resource
resource "aws_key_pair" "consul" {
  key_name   = "consul_key"
  public_key = "${file(module.global_variables.ssh_public_key_path)}"
}

# Create our security group for the instance
resource "aws_security_group" "consul" {
  name   = "consul_security_group"
  vpc_id = "${data.aws_vpc.default.id}"

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "8500"
    to_port     = "8500"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create our security group for the LB
resource "aws_security_group" "consul_lb" {
  name   = "consul_lb_security_group"
  vpc_id = "${data.aws_vpc.default.id}"

  ingress {
    from_port   = "8500"
    to_port     = "8500"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the test consul instance
resource "aws_instance" "consul" {
  ami           = "${module.global_variables.aws_coreos_ami}"
  instance_type = "${var.instance_type}"
  user_data     = "${file("cloud-init")}"

  #subnet_id              = "${data.aws_subnet.default.id}"
  subnet_id              = "${element(data.aws_subnet_ids.default.ids, count.index)}"
  vpc_security_group_ids = ["${aws_security_group.consul.id}"]

  key_name = "${aws_key_pair.consul.key_name}"

  associate_public_ip_address = true

  tags {
    Name    = "${var.server_name}"
    cluster = "${var.server_name}"
    Source  = "Terraform Task Scheduler"
  }
}

## Setup Load balancer

# Setup target group for the load balancer
resource "aws_lb_target_group" "consul_lb" {
  name     = "consul-target-group"
  port     = "${var.consul_port}"
  protocol = "${var.consul_protocol}"
  vpc_id   = "${data.aws_vpc.default.id}"

  health_check {
    healthy_threshold = 2
    interval          = 10
    path              = "/"
    matcher           = "200,301" # the path / returns a 301
  }

  tags {
    Name   = "Consul target group"
    Source = "Terraform Task Scheduler"
  }
}

# Register the instances to the target group
resource "aws_lb_target_group_attachment" "consul_lb" {
  target_group_arn = "${aws_lb_target_group.consul_lb.arn}"
  target_id        = "${aws_instance.consul.id}"
  port             = "${var.consul_port}"
}

# Create the load balancer
resource "aws_lb" "consul_lb" {
  name               = "consul-lb"
  internal           = true
  load_balancer_type = "application"

  #subnets            = ["${data.aws_subnet.default.id}"]
  subnets = ["${data.aws_subnet.default.*.id}"]

  security_groups = ["${aws_security_group.consul_lb.id}"]

  enable_deletion_protection = false

  tags {
    Source = "Terraform Task Scheduler"
  }
}

# Create a listener for the load balancer
resource "aws_lb_listener" "consul_lb" {
  load_balancer_arn = "${aws_lb.consul_lb.arn}"
  port              = "${var.consul_port}"
  protocol          = "${var.consul_protocol}"

  default_action {
    target_group_arn = "${aws_lb_target_group.consul_lb.arn}"
    type             = "forward"
  }
}
