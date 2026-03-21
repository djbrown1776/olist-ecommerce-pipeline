terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 2
}

provider "aws" {
  region = var.region
}

data "aws_secretsmanager_secret" "kaggle_token" {
  name = "kaggle-api-token"
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.bucket_name}-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "My bucket"
    Environment = var.environment
  }
}

# Versioning 
resource "aws_s3_bucket_versioning" "data_versioning" {
  bucket = aws_s3_bucket.data_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# BLOCK PUBLIC ACCESS
resource "aws_s3_bucket_public_access_block" "data_pab" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ENCRYPTION AT REST
resource "aws_s3_bucket_server_side_encryption_configuration" "data_encryption" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_role_policy" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Access 
resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.pipeline_name}-secrets-access"
  role = aws_iam_role.execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [data.aws_secretsmanager_secret.kaggle_token.arn]
    }]
  })
}

# ECR Repository 
resource "aws_ecr_repository" "this" {
  name                 = var.pipeline_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# CloudWatch Log ECS
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.pipeline_name}"
  retention_in_days = 30
}

# ECS Cluster 
resource "aws_ecs_cluster" "this" {
  name = "${var.pipeline_name}-cluster"
}

# Task Role 
resource "aws_iam_role" "task_role" {
  name = "${var.pipeline_name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "${var.pipeline_name}-s3-access"
  role = aws_iam_role.task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:PutObject"]
      Resource = [
        var.s3_bucket_arn,
        "${var.s3_bucket_arn}/*"
      ]
    }]
  })
}

# Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = var.pipeline_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  runtime_platform {
    cpu_architecture        = var.cpu_architecture
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = var.pipeline_name
    image     = "${aws_ecr_repository.this.repository_url}:latest"
    essential = true
    secrets = [{
      name      = "KAGGLE_API_TOKEN"
      valueFrom = data.aws_secretsmanager_secret.kaggle_token.arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# Glue IAM Role
resource "aws_iam_role" "glue_role" {
  name = "${var.pipeline_name}-glue-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.pipeline_name}-glue-s3-access"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.data_bucket.arn,
        "${aws_s3_bucket.data_bucket.arn}/*"
      ]
    }]
  })
}

# Glue job 
resource "aws_glue_job" "transform" {
  name     = "${var.pipeline_name}-transform"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.data_bucket.bucket}/scripts/transform.py"
    python_version  = "3"
  }

  default_arguments = {
    "--S3_BUCKET"                        = aws_s3_bucket.data_bucket.bucket
    "--RAW_PREFIX"                       = "raw"
    "--SILVER_PREFIX"                    = "silver"
    "--job-language"                     = "python"
    "--enable-continuous-cloudwatch-log" = "true"
  }

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30
  max_retries       = 0
}

# CloudWatch Log Glue
resource "aws_cloudwatch_log_group" "glue" {
  name              = "/aws-glue/jobs/${var.pipeline_name}-transform"
  retention_in_days = 30
}

# Redshift IAM Role

resource "aws_iam_role" "redshift" {
  name = "${var.pipeline_name}-redshift-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "redshift_s3_read" {
  name = "${var.pipeline_name}-redshift-s3-read"
  role = aws_iam_role.redshift.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Redshift Namespace

resource "aws_redshiftserverless_namespace" "this" {
  namespace_name      = "${var.pipeline_name}-namespace"
  db_name             = var.redshift_db_name
  admin_username      = var.redshift_admin_username
  admin_user_password = var.redshift_admin_password
  iam_roles           = [aws_iam_role.redshift.arn]

  tags = {
    Project = var.pipeline_name
  }
}

# Redshift Security Group

resource "aws_security_group" "redshift" {
  name        = "${var.pipeline_name}-redshift-sg"
  description = "Allow inbound access to Redshift Serverless"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redshift port"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.pipeline_name
  }
}

# Redshift Workgroup 

resource "aws_redshiftserverless_workgroup" "this" {
  workgroup_name      = "${var.pipeline_name}-workgroup"
  namespace_name      = aws_redshiftserverless_namespace.this.namespace_name
  base_capacity       = 8
  publicly_accessible = true
  security_group_ids  = [aws_security_group.redshift.id]

  tags = {
    Project = var.pipeline_name
  }
}