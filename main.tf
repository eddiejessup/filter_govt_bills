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

resource "aws_ecs_cluster" "cluster" {
  name = "filter-govt-bills"
}

resource "aws_ecs_task_definition" "task" {
  family                   = "filter-govt-bills"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 1024
  network_mode             = "awsvpc"
  execution_role_arn       = "arn:aws:iam::125839941772:role/ecs-execution"
  container_definitions = jsonencode([
    {
      name      = "filter-govt-bills"
      image     = "125839941772.dkr.ecr.eu-west-1.amazonaws.com/filter-govt-bills:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
        }
      ],
      environment = [
        { "name" : "PORT", "value" : "80" }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/filter-govt-bills"
          "awslogs-region"        = "eu-west-1"
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
      "subnet-091146fb6d105e214",
      "subnet-f91e609c",
    ]
    security_groups  = ["sg-81a3ace4"]
    assign_public_ip = true
  }
}

resource "aws_cloudwatch_event_rule" "ecs_task_state_change" {
  name        = "ecs-task-state-change"
  description = "Capture ECS task state change events"

  event_pattern = jsonencode({
    source      = ["aws.ecs"],
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn = [aws_ecs_cluster.cluster.arn]
      lastStatus = ["RUNNING"]
    }
  })
}

data "aws_iam_policy_document" "assume_role" {
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
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "ecs_task_state_change" {
  function_name    = "route53_sync"
  role             = aws_iam_role.lambda_role.arn
  filename         = "lambda_function_payload.zip"
  runtime          = "python3.10"
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
}

resource "aws_cloudwatch_event_target" "ecs_task_state_change_target" {
  rule      = aws_cloudwatch_event_rule.ecs_task_state_change.name
  arn       = aws_lambda_function.ecs_task_state_change.arn
  target_id = "EcsTaskStateChangeLambdaTarget"
}
