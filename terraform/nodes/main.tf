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
resource "aws_key_pair" "node" {
  key_name   = "node_key"
  public_key = "${file(module.global_variables.ssh_public_key_path)}"
}

# Create our security group for the instance
resource "aws_security_group" "node" {
  name   = "node_security_group"
  vpc_id = "${data.aws_vpc.default.id}"

  ingress {
    from_port   = "22"
    to_port     = "22"
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

# Get our LB id filtered by tags
data "aws_lb" "consul_lb" {
  tags {
    Name   = "Consul target group"
    Source = "Terraform Task Scheduler"
  }
}

# Addd Consul LB DNS name to cloud init
data "template_file" "cloud_init" {
  template = "${file("cloud-init.tpl")}"

  vars {
    consul_address      = "${data.aws_lb.consul_lb.dns_name}"
    task_id             = "${var.task_id}"
    task_period         = "${var.task_period}"
    task_command        = "${var.task_command}"
    timer_mins          = "${var.timer_mins}"
    slack_webhook       = "${var.slack_webhook}"
    datadog_api_key     = "${var.datadog_api_key}"
    COREOS_PRIVATE_IPV4 = "$${COREOS_PRIVATE_IPV4}"
  }
}

# Create the test nodes
resource "aws_instance" "node" {
  ami                    = "${module.global_variables.aws_coreos_ami}"
  instance_type          = "${var.instance_type}"
  user_data              = "${data.template_file.cloud_init.rendered}"
  count                  = "${var.node_count}"
  subnet_id              = "${element(data.aws_subnet_ids.default.ids, count.index)}"
  vpc_security_group_ids = ["${aws_security_group.node.id}"]

  key_name = "${aws_key_pair.node.key_name}"

  associate_public_ip_address = true

  # Copy schedule-tasks.sh /etc/systemd/system/
  provisioner "file" {
    connection {
      user        = "core"
      private_key = "${file("${module.global_variables.ssh_private_key_path}")}"
    }

    source      = "../../scripts/schedule-tasks.sh"
    destination = "/home/core/schedule-tasks.sh"
  }

  # Make /home/core/schedule-tasks.sh executable
  provisioner "remote-exec" {
    connection {
      user        = "core"
      private_key = "${file("${module.global_variables.ssh_private_key_path}")}"
    }

    inline = [
      "chmod +x /home/core/schedule-tasks.sh",
    ]
  }

  tags {
    Name   = "${var.server_name}-${count.index}"
    Source = "Terraform Task Scheduler"
  }
}
