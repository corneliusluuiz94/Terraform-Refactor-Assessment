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
  cidr_block = "10.0.0.0/16"

  tags = merge(local.common_tags, {
    Name = "main-vpc-${local.environment}"
  })
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = merge(local.common_tags, {
    Name = "public-subnet-${local.environment}"
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
  ami                    = "ami-0c101f26f147fa7fd" # Amazon Linux 2023, us-east-1 - verify/update before applying
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = merge(local.common_tags, {
    Name = "web-instance-${local.environment}"
  })
}

# --- Storage ---
resource "aws_s3_bucket" "app_bucket" {
  bucket = "corneliusluuiz94-app-bucket-${local.environment}" # bucket names are globally unique - edit before apply

  tags = merge(local.common_tags, {
    Name = "app-bucket-${local.environment}"
  })
}

# --- Monitoring ---
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "high-cpu-usage-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  alarm_description = "This alarm monitors EC2 CPU utilization"

  tags = local.common_tags
}
