variable "server_name" {
  description = "Server name"
  type        = "string"
  default     = "node"
}

variable "node_count" {
  description = "The number of nodes initially provisioned"
  type        = "string"
  default     = "2"
}

variable "instance_type" {
  description = "Instance Type"
  type        = "string"
  default     = "t2.micro"
}

variable "task_id" {
  description = "Task id that is sent to consul"
  type        = "string"
  default     = "test"
}

variable "task_period" {
  description = "How often the distributed task should run in seconds"
  type        = "string"
  default     = "3600"
}

variable "task_command" {
  description = "The command the task should run"
  type        = "string"
  default     = "/usr/bin/touch worked"
}

variable "timer_mins" {
  description = "How often the task service should check if a task can be run in minutes"
  type        = "string"
  default     = "10"
}

variable "slack_webhook" {
  description = "Slack webhook to post tasks status"
  type        = "string"
  default     = "https://hooks.slack.com/services/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" #<- throw away slack webhook
}

variable "datadog_api_key" {
  description = "DataDog API Key"
  type        = "string"
  default     = "xxxxx"
}
