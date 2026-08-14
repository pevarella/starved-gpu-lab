variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "eks-gpu-lab"
}

variable "budget_email" {
  description = "Email used to receive AWS Budget alterts"
  type        = string
}