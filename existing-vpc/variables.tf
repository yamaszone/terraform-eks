variable "region" {
}

variable "vpc_id" {
  description = "ID of your existing VPC"
}

variable "subnets" {
  description = "List of public subnets"
  type        = "list"
}

