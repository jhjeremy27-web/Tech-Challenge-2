variable "aws_region" {
  description = "AWS region used for Tech Challenge 2"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Base name used for project resources"
  type        = string
  default     = "tech-challenge-2"
}

variable "kubernetes_version" {
  description = "Amazon EKS Kubernetes version"
  type        = string
  default     = "1.36"
}