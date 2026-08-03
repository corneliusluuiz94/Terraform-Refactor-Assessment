# --- Locals ---
# Environment is derived from the active workspace, never typed manually.
locals {
  environment = terraform.workspace

  common_tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# --- Networking ---
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = merge(local.common_tags, {
    Name = "main-vpc-${local.environment}"
  })
}

resource "aws_subnet" "public" {
  for_each = toset(var.availability_zones) 

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, index(var.availability_zones, each.value))
  availability_zone = each.value

  tags = merge(local.common_tags, {
    Name = "public-subnet-${each.value}-${local.environment}"
  })
}

# --- Security ---
resource "aws_security_group" "web_sg" {
  name        = "web-sg-${local.environment}"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "web-sg-${local.environment}"
  })
}

# --- Compute ---
resource "aws_instance" "web" {
  count = var.instance_count
  ami                    = "ami-0c101f26f147fa7fd" # Amazon Linux 2023, us-east-1 - verify/update before applying
  instance_type          = var.instance_type_map[local.environment]
  subnet_id              = values(aws_subnet.public)[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = merge(local.common_tags, {
    Name = "web-instance-${count.index}-${local.environment}"
  })
}

# --- Storage ---
resource "aws_s3_bucket" "app_bucket" {
  bucket = "corneliusluuiz94-app-bucket-${local.environment}" # bucket names are globally unique - edit before apply

  tags = merge(local.common_tags, {
    Name = "app-bucket-${local.environment}"
  })
}
# Versioning is a separate resource in the AWS provider (not an attribute
# on aws_s3_bucket). Enabled in staging/prod; left off in dev to avoid
# piling up noise from throwaway test objects.
resource "aws_s3_bucket_versioning" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  versioning_configuration {
    status = contains(["staging", "prod"], local.environment) ? "Enabled" : "Suspended"
  }
}


# --- Monitoring ---
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  # count = 0 in dev/staging means this resource simply doesn't exist there -
  # not "exists but disabled."
  count = local.environment == "prod" ? 1 : 0

  alarm_name          = "high-cpu-usage-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.web[0].id
  }

  alarm_description = "This alarm monitors EC2 CPU utilization"

  tags = local.common_tags
}
