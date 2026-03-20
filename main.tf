# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    es             = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    route53        = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    sts            = "http://localhost:4566"
    elb            = "http://localhost:4566"
    elbv2          = "http://localhost:4566"
    rds            = "http://localhost:4566"
    autoscaling    = "http://localhost:4566"
    events         = "http://localhost:4566"
  }
}

# IAM Role: Identity for EC2 instances to communicate with Systems Manager (SSM)
resource "aws_iam_role" "ssm_fleet_role" {
  name = "ssm-fleet-management-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "ssm-fleet-role"
    Environment = "SysOps-Lab"
  }
}

# VPC: The foundational network for our fleet management architecture
resource "aws_vpc" "fleet_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "fleet-management-vpc"
    Environment = "SysOps-Lab"
  }
}

# Subnets: Two subnets in different Availability Zones for high availability
resource "aws_subnet" "fleet_subnet_a" {
  vpc_id            = aws_vpc.fleet_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "fleet-subnet-a"
    Environment = "SysOps-Lab"
  }
}

resource "aws_subnet" "fleet_subnet_b" {
  vpc_id            = aws_vpc.fleet_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name        = "fleet-subnet-b"
    Environment = "SysOps-Lab"
  }
}

# IAM Policy Attachment: Grants the role the standard SSM core permissions
resource "aws_iam_role_policy_attachment" "ssm_fleet_policy" {
  role       = aws_iam_role.ssm_fleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile: The container for our SSM role
resource "aws_iam_instance_profile" "ssm_fleet_profile" {
  name = "ssm-fleet-management-profile"
  role = aws_iam_role.ssm_fleet_role.name
}

# Launch Template: The versioned blueprint for our fleet instances
resource "aws_launch_template" "fleet_template" {
  name_prefix   = "ssm-fleet-template"
  image_id      = "ami-03cf127a" # Valid LocalStack AMI
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_fleet_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "ssm-managed-fleet-instance"
      Environment = "SysOps-Lab"
    }
  }
}

# Auto Scaling Group: Manages our fleet of SSM-ready instances
resource "aws_autoscaling_group" "fleet_asg" {
  name                = "ssm-managed-fleet"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.fleet_subnet_a.id, aws_subnet.fleet_subnet_b.id]

  launch_template {
    id      = aws_launch_template.fleet_template.id
    version = "$Latest"
  }

  # SysOps Best Practice: Use instance refresh for automated rolling updates
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "ssm-managed-fleet-instance"
    propagate_at_launch = true
  }
}

# EventBridge Rule: Monitors the status of ASG Instance Refreshes
resource "aws_cloudwatch_event_rule" "instance_refresh_rule" {
  name        = "asg-instance-refresh-monitor"
  description = "Triggers when an ASG instance refresh starts or finishes"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail_type = ["EC2 Instance Refresh Succeeded", "EC2 Instance Refresh Failed", "EC2 Instance Refresh Started"]
  })

  tags = {
    Name        = "refresh-monitor"
    Environment = "SysOps-Lab"
  }
}

# Outputs: Key identifiers for fleet management and secure access
output "asg_name" {
  value = aws_autoscaling_group.fleet_asg.name
}

output "launch_template_id" {
  value = aws_launch_template.fleet_template.id
}

output "vpc_id" {
  value = aws_vpc.fleet_vpc.id
}
