
variable "metaflow_vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "bucket_name_prefix" {
  type        = string
  description = "Naming prefix of an S3 bucket for metaflow data"
  default     = "metaflow"
}

variable "compute_environment_name" {
  type        = string
  description = "name of the AWS batch compute environment"
  default     = "metaflow"
}

variable "ecs_instance_role_name" {
  type        = string
  description = "Name of the ECS IAM instance role"
  default     = "metaflow_ecs_instance_role"
}

variable "batch_security_group_name" {
  type        = string
  description = "Name of the security group used for tasks in the AWS batch compute environment"
  default     = "metaflow_batch_compute_security_group"
}

variable "batch_service_role_name" {
  type        = string
  description = "Name of the AWS batch service IAM role"
  default     = "aws_batch_service_role"
}

variable "batch_instance_types" {
  type        = list(string)
  description = "EC2 instance types to use for AWS batch jobs"
  default     = ["optimal","p2","p3"]
}

variable "batch_max_vcpu" {
  type        = string
  description = "maximum number of vCPUs to use on a batch job; defaults to 32"
  default     = 32
}

variable "batch_min_vcpu" {
  type        = string
  description = "minimum number of vCPUs to use on a batch job; defaults to 2"
  default     = 2
}

variable "batch_queue_name" {
  type        = string
  description = "Name of AWS batch queue"
  default     = "metaflow"
}

variable "batch_subnet_name" {
  type        = string
  description = "Name of AWS batch compute subnet"
  default     = "metaflow-public-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile to use with this terraform config; defaults to 'default'"
  default     = "default"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy to; defaults to 'us-east-1'"
  default     = "us-east-1"
}

variable "bid_percentage" {
  type = string
  description = "Spot bid percentage for AWS Batch compute"
  default = "100"
}
