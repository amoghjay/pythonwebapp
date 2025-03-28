variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "dev"
}
variable "aws_region" {
  description = "AWS region to use"
  type        = string
  default     = "us-east-1"

}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "my-vpc-new"

}

variable "igw_name" {
  description = "Name of the Internet Gateway"
  type        = string
  default     = "my-igw"

}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_name" {
  description = "Name of the public subnets"
  type        = string
  default     = "my-public-subnet"

}

variable "destination_public_cidr" {
  description = "Destination CIDR block for the public route"
  type        = string
  default     = "0.0.0.0/0"
}
variable "private_subnet_name" {
  description = "Name of the private subnets"
  type        = string
  default     = "my-private-subnet"

}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "aws_ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-095427c88bfb0b00e"

}

variable "aws_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "aws_key_name" {
  description = "Name of the key pair to use for SSH access"
  type        = string
  default     = "devkey"

}

variable "aws_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 25

}

variable "aws_volume_type" {
  description = "Type of the root volume"
  type        = string
  default     = "gp2"

}

variable "s3_bucket_prefix" {
  description = "Prefix for the S3 bucket name (UUID will be appended)"
  default     = "webapp-bucket"
}



variable "DB_USERNAME" {
  description = "Database username"
  type        = string
  default     = "csye6225"

}

variable "DB_NAME" {
  description = "Database name"
  type        = string
  default     = "csye6225"

}

variable "DB_PASSWORD" {
  description = "Database password"
  type        = string

}