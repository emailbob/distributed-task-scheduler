output "aws_region" {
  description = "AWS Region to deploy infrastructure in"
  value       = "us-east-2"
}

output "aws_coreos_ami" {
  description = "AWS CoreOS ami"
  value       = "ami-5bf4ca3e"
}

output "ssh_public_key_path" {
  description = "SSH public key used to connect to server"
  value       = "~/.ssh/mp-ssh-key.pub"
}

output "ssh_private_key_path" {
  description = "SSH private key used to connect to server"
  value       = "~/.ssh/mp-ssh-key"
}
