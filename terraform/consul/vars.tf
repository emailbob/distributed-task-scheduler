variable "server_name" {
  description = "Server name"
  type        = "string"
  default     = "console"
}

variable "instance_type" {
  description = "Instance Type"
  type        = "string"
  default     = "t2.micro"
}

variable "consul_port" {
  description = "Consul port"
  type        = "string"
  default     = "8500"
}

variable "consul_protocol" {
  description = "Consul protocol"
  type        = "string"
  default     = "HTTP"
}
