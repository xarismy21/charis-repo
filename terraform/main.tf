provider "aws" {
  region = "us-east-1"
}

resource "aws_ecs_cluster" "charis_cluster" {
  name = "charis-devops-cluster"
}

resource "aws_ecs_task_definition" "charis_task" {
  family                   = "charis-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name  = "charis-api"
      image = "charis-api:latest"
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
}
