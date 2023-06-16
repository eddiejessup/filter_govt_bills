terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-1"
}

variable "image_url" {
  description = "URL of the Docker image to use"
  type        = string
}

variable "port" {
  description = "Port that the application should listen on"
  type        = number
}

variable "domain" {
  description = "The name of the domain to serve the application at"
  type        = string
}

variable "subdomain" {
  description = "The name of the sub-domain to serve the application at"
  type        = string
}

locals {
  lambda_source_module_name = "lambda"
}

data "aws_region" "current" {}

# Assumed to be 172.31.0.0/16
# """
# The aws_default_vpc resource behaves differently from normal resources
# in that if a default VPC exists, Terraform does not create this resource,
# but instead "adopts" it into management.
# """
resource "aws_default_vpc" "default" {
}

resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_default_vpc.default.id
  cidr_block = "172.31.32.0/24"
}

resource "aws_subnet" "subnet_2" {
  vpc_id     = aws_default_vpc.default.id
  cidr_block = "172.31.33.0/24"
}

resource "aws_security_group" "main" {
  vpc_id = aws_default_vpc.default.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
}

resource "aws_ecs_cluster" "cluster" {
  name = "filter-govt-bills"
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "ecs_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "task" {
  family                   = "filter-govt-bills"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "filter-govt-bills"
      image     = var.image_url
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = var.port
        }
      ],
      environment = [
        { "name" : "PORT", "value" : tostring(var.port) }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/filter-govt-bills"
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "service" {
  name            = "filter-govt-bills"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets = [
      aws_subnet.subnet_1.id,
      aws_subnet.subnet_2.id,
    ]
    security_groups  = [aws_security_group.main.id]
    assign_public_ip = true
  }
}

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eventbridge_role" {
  name               = "eventbridge_role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
}

resource "aws_iam_role_policy" "eventbridge_lambda_policy" {
  name = "eventbridge_lambda_policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction",
        ],
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "ecs_task_state_change" {
  name        = "ecs-task-state-change"
  description = "Capture ECS task state change events"
  role_arn    = aws_iam_role.eventbridge_role.arn

  event_pattern = jsonencode({
    source      = ["aws.ecs"],
    detail-type = ["ECS Task State Change"],
    detail = {
      clusterArn    = [aws_ecs_cluster.cluster.arn],
      lastStatus    = ["RUNNING"]
      desiredStatus = ["RUNNING"]
    }
  })
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ecs_policy" {
  name = "lambda_ecs_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:DescribeTasks",
          "ec2:DescribeNetworkInterfaces",
          "route53:ChangeResourceRecordSets",
          "route53:ListHostedZones",
        ],
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${local.lambda_source_module_name}.py"
  output_path = "lambda_function_payload.zip"
}

data "aws_route53_zone" "existing" {
  name = var.domain
}

resource "aws_lambda_function" "ecs_task_state_change" {
  function_name    = "route53_sync"
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.lambda.output_path
  runtime          = "python3.10"
  handler          = "${local.lambda_source_module_name}.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      DOMAIN         = "${var.subdomain}.${var.domain}"
      HOSTED_ZONE_ID = data.aws_route53_zone.existing.id
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_task_state_change.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_task_state_change.arn
}

resource "aws_cloudwatch_event_target" "ecs_task_state_change_target" {
  rule      = aws_cloudwatch_event_rule.ecs_task_state_change.name
  arn       = aws_lambda_function.ecs_task_state_change.arn
  target_id = "EcsTaskStateChangeLambdaTarget"
}
