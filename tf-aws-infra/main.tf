# main.tf
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name = "${var.public_subnet_name}-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name = "${var.private_subnet_name}-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = var.igw_name
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.destination_public_cidr
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.vpc_name}-public"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-private"
  }
}

# Associations
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Creating Security Group for Web Application
resource "aws_security_group" "app_sg" {
  name        = "app_security_group"
  description = "Allow web traffic and SSH"
  vpc_id      = aws_vpc.main.id # Use the created VPC

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows SSH access
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP traffic
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS traffic
  }

  ingress {
    from_port   = 8080 # Web Application port
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating S3 Bucket for Web Application 
resource "random_uuid" "s3_bucket_uuid" {}

resource "aws_s3_bucket" "webapp_s3" {
  bucket        = "${var.s3_bucket_prefix}-${random_uuid.s3_bucket_uuid.result}"
  force_destroy = true # Allows deletion even if the bucket contains objects

  tags = {
    Name        = "WebApp S3 Bucket"
    Environment = "Dev"
  }
}

# 🔹 Enable Default Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "webapp_s3_encryption" {
  bucket = aws_s3_bucket.webapp_s3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 🔹 Lifecycle Rule to Transition Objects
resource "aws_s3_bucket_lifecycle_configuration" "webapp_s3_lifecycle" {
  bucket = aws_s3_bucket.webapp_s3.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

#Custom IAM policy for the S3 bucket

resource "aws_iam_policy" "s3_access_policy" {
  name        = "EC2S3AccessPolicy"
  description = "Allows EC2 to access S3 bucket created in Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.webapp_s3.id}",
          "arn:aws:s3:::${aws_s3_bucket.webapp_s3.id}/*"
        ]
      }
    ]
  })
}

#Creating IAM Role for EC2 Instance
resource "aws_iam_role" "ec2_s3_role" {
  name = "EC2S3AccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the S3 access policy to the role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.ec2_s3_role.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy_attachment" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Define IAM instance profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2InstanceProfile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id # Ensure this matches your VPC

  # Allow inbound traffic from the EC2 instance security group on port 5432
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Only allow EC2 access
    description     = "Allow PostgreSQL access from EC2"
  }

  # Allow all outbound traffic (so RDS can respond to EC2 requests)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS-Security-Group"
  }
}

resource "aws_db_subnet_group" "webapp_rds_subnet_group" {
  name        = "webapp-rds-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids  = [aws_subnet.private[0].id, aws_subnet.private[1].id] # Use at least two private subnets

  tags = {
    Name = "WebApp-RDS-Subnet-Group"
  }
}

resource "aws_db_parameter_group" "webapp_rds_param_group" {
  name        = "webapp-rds-param-group"
  family      = "postgres17" # Match the PostgreSQL version
  description = "Custom parameter group for WebApp RDS"
}

resource "aws_db_instance" "webapp_rds" {
  identifier          = "csye6225"
  allocated_storage   = 20
  storage_type        = "gp2"
  engine              = "postgres"
  engine_version      = "17"
  instance_class      = "db.t3.micro"
  username            = var.DB_USERNAME
  password            = var.DB_PASSWORD
  db_name             = var.DB_NAME
  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true

  # Use the latest PostgreSQL 17 parameter group
  parameter_group_name = aws_db_parameter_group.webapp_rds_param_group.name

  # Attach the RDS Security Group
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Specify the RDS subnet group
  db_subnet_group_name = aws_db_subnet_group.webapp_rds_subnet_group.name


  tags = {
    Name = "WebApp-RDS"
  }
}


# Creating EC2 Instance in Public Subnet
resource "aws_instance" "app_instance" {
  ami                         = var.aws_ami_id
  instance_type               = var.aws_instance_type
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  subnet_id                   = aws_subnet.public[0].id #using the first public subnet for now
  associate_public_ip_address = true                    # Ensure it gets a public IP
  key_name                    = var.aws_key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name # Attach IAM role ${aws_s3_bucket.webapp_s3.id}

  user_data = <<-EOF
              #!/bin/bash
              cat > /opt/csye6225/webapp/.env << EOL
              DATABASE_URL=postgresql://${var.DB_USERNAME}:${var.DB_PASSWORD}@${aws_db_instance.webapp_rds.address}:5432/${var.DB_NAME}
              S3_BUCKET=${aws_s3_bucket.webapp_s3.id}
              EOL
              systemctl daemon-reload
              systemctl restart csye6225.service
              sudo systemctl restart amazon-cloudwatch-agent
              sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                  -a fetch-config \
                  -m ec2 \
                  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
                  -s
              EOF


  root_block_device {
    volume_size           = var.aws_volume_size
    volume_type           = var.aws_volume_type
    delete_on_termination = true
  }

  tags = {
    Name = "WebAppInstance"
  }
}