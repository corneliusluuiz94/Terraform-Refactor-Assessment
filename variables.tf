variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources into"
}

variable "aws_profile" {
  type        = string
  description = "Named AWS CLI profile to authenticate with (not the default profile)"
}

# --- Loops (Feature 4) ---

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones to create one subnet per"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_count" {
  type        = number
  description = "Number of web EC2 instances to deploy"
  default     = 1
}
variable "instance_type_map" {
  type        = map(string)
  description = "EC2 instance type per environment"
  default = {
    dev     = "t2.micro"
    staging = "t3.small"
    prod    = "t3.medium"
  }
}
