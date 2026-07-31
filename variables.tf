variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources into"
}

variable "aws_profile" {
  type        = string
  description = "Named AWS CLI profile to authenticate with (not the default profile)"
}