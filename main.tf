resource "aws_iam_role" "spot_fleet_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "spotfleet.amazonaws.com"
        ]
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "metaflow_ecs_execution_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com",
          "ecs.amazonaws.com",
          "ecs-tasks.amazonaws.com",
          "batch.amazonaws.com"
        ]
      }
    }
  ]
}
EOF
}

# Create IAM role for ECS instances
resource "aws_iam_role" "ecs_instance_role" {
  name = var.ecs_instance_role_name

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "ec2.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "spot_fleet_role" {
  role       = aws_iam_role.spot_fleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_policy_attachment" "ecs_execution_role" {
  name = "metaflow-attachment"
  roles = [aws_iam_role.ecs_execution_role.name]
  policy_arn = aws_iam_policy.metaflow.arn
}

resource "aws_iam_instance_profile" "ecs_instance_role" {
  name = var.ecs_instance_role_name
  role = aws_iam_role.ecs_instance_role.name
}

# Create a S3 bucket for storing metaflow data
# otherwise stored locally in .metaflow directory
resource "aws_s3_bucket" "metaflow" {
  bucket_prefix = var.bucket_name_prefix
  acl    = "private"

  tags = {
    Metaflow = "true"
  }
}

resource "aws_iam_policy" "metaflow" {
  name = "metaflow"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEcsInstance",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "${aws_s3_bucket.metaflow.arn}",
        "${aws_s3_bucket.metaflow.arn}/*"
      ]
    },
    {
      "Sid": "AllowEcsExecution",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "${aws_s3_bucket.metaflow.arn}",
        "${aws_s3_bucket.metaflow.arn}/*"
      ]
    },
    {
      "Sid": "AllowBatchService",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "${aws_s3_bucket.metaflow.arn}",
        "${aws_s3_bucket.metaflow.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "aws_batch_service_role" {
  name = var.batch_service_role_name

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": [
            "batch.amazonaws.com",
            "s3.amazonaws.com"
          ]
        }
    }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_security_group" "metaflow_batch" {
  name       = var.batch_security_group_name
  vpc_id     = aws_vpc.metaflow.id
  depends_on = [aws_vpc.metaflow]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Metaflow = "true"
  }
}

# Create VPC for Batch jobs to run in
resource "aws_vpc" "metaflow" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "metaflow-vpc"
    Metaflow = "true"
  }
}

resource "aws_internet_gateway" "metaflow" {
  vpc_id = aws_vpc.metaflow.id
  tags = {
    Metaflow = "true"
  }
}

# Create a subnet per availability zone in the region
data "aws_availability_zones" "available" {}

resource "aws_subnet" "metaflow_batch_subnets" {
  count = length(data.aws_availability_zones.available.names)
  vpc_id = aws_vpc.metaflow.id
  cidr_block = cidrsubnet(var.metaflow_vpc_cidr, 8, count.index) # https://www.terraform.io/docs/configuration/functions/cidrsubnet.html
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Metaflow = "true"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.metaflow.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.metaflow.id
  }

  tags = {
    Name     = "Public Subnet"
    Metaflow = "true"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.metaflow_batch_subnets.*.id)

  subnet_id      = element(aws_subnet.metaflow_batch_subnets.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Changing certain properties or doing a destroy runs into a longstanding issue.
# See: https://github.com/terraform-providers/terraform-provider-aws/issues/2044
resource "aws_batch_compute_environment" "metaflow_batch" {
  compute_environment_name = var.compute_environment_name

  compute_resources {
    instance_role = aws_iam_instance_profile.ecs_instance_role.arn

    instance_type = var.batch_instance_types
    allocation_strategy = "SPOT_CAPACITY_OPTIMIZED"

    max_vcpus     = var.batch_max_vcpu
    min_vcpus     = 0

    security_group_ids = [
      aws_security_group.metaflow_batch.id,
    ]

    subnets = [
    for subnet in aws_subnet.metaflow_batch_subnets:
    subnet.id
    ]

    type = "SPOT"
    spot_iam_fleet_role = aws_iam_role.spot_fleet_role.arn
    bid_percentage = var.bid_percentage

    tags = {
      Metaflow = "true"
    }
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.aws_batch_service_role]
}

# Create the Batch Job Queue
resource "aws_batch_job_queue" "metaflow_batch_job_queue" {
  name                 = var.batch_queue_name
  state                = "ENABLED"
  priority             = 1
  compute_environments = [aws_batch_compute_environment.metaflow_batch.arn]
}

resource "aws_iam_role" "iam_s3_access_role" {
  name               = "metaflow_iam_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com",
          "ecs.amazonaws.com",
          "ecs-tasks.amazonaws.com",
          "batch.amazonaws.com",
          "s3.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Metaflow = "true"
  }
}

resource "aws_iam_role_policy" "iam_metaflow_s3_access_policy" {
  name = "metaflow_s3_access"
  role = aws_iam_role.iam_s3_access_role.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "ListObjectsInBucket",
        "Effect": "Allow",
        "Action": ["s3:*"],
        "Resource": ["${aws_s3_bucket.metaflow.arn}", "${aws_s3_bucket.metaflow.arn}/*"]
    }
  ]
}
EOF
}
