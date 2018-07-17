output "public_ip" {
  value = "${aws_instance.consul.public_ip}"
}

output "access_consul" {
  value = "http://${aws_instance.consul.public_ip}:8500"
}

output "lb_dns" {
  value = "${aws_lb.consul_lb.dns_name}"
}
