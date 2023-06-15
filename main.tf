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
  name = "filter-govt-bills-tf"
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
