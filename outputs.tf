output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "instance_ids" {
  description = "IDs of all web EC2 instances"
  value       = aws_instance.web[*].id
}

output "instance_public_ips" {
  description = "Public IPs of all web EC2 instances"
  value       = aws_instance.web[*].public_ip
}

output "s3_bucket_name" {
  description = "Name of the application S3 bucket"
  value       = aws_s3_bucket.app_bucket.bucket
}

output "cloudwatch_alarm_created" {
  description = "Whether the CPU CloudWatch alarm was created in this environment (prod only)"
  value       = local.environment == "prod"
}
