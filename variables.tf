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

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "availability_zones must contain at least one AZ."
  }
}
 
variable "instance_count" {
  type        = number
  description = "Number of web EC2 instances to deploy"
  default     = 1

   validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

variable "instance_type_map" {
  type        = map(string)
  description = "EC2 instance type per environment"
  default = {
    dev     = "t2.micro"
    staging = "t3.small"
    prod    = "t3.medium"
  }
  
  validation {
    condition     = alltrue([for env in ["dev", "staging", "prod"] : contains(keys(var.instance_type_map), env)])
    error_message = "instance_type_map must include an entry for each of: dev, staging, prod."
  }
}










