# ecs.tf

resource "aws_ecs_cluster" "main" {
  name = "AIOPS-cluster"
  tags = {
    Environment = "AIOPS"
    Project     = "POC"
  }
}

/*data "template_file" "AIOPS" {
  template = file("./templates/ecs/AIOPS.json.tpl")

  vars = {
    app_image      = var.app_image
    app_port       = var.app_port
    fargate_cpu    = var.fargate_cpu
    fargate_memory = var.fargate_memory
    aws_region     = var.aws_region
  }
}*/

resource "aws_ecs_task_definition" "app" {
  family                   = "AIOPS-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions = jsonencode([{
    name  = "my-app-container"
    image = var.app_image
    portMappings = [{
      containerPort = var.app_port,
      hostPort      = var.app_port,
    }]

    environment = [
      { name = "DB_HOST", value = tostring(aws_db_instance.rds_instance.rds_endpoint) },
      { name = "DB_USER", value = "root" },
      { name = "DB_PASSWORD", value = "password" },
      { name = "DB_NAME", value = "user_management" },
    ]
  }])
  tags = {
    Environment = "AIOPS"
    Project     = "POC"
  }
  depends_on = [aws_db_instance.rds_instance]
}

resource "aws_ecs_service" "main" {
  name            = "AIOPS-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "AIOPS"
    container_port   = var.app_port
  }
  tags = {
    Environment = "AIOPS"
    Project     = "POC"
  }

  depends_on = [aws_alb_listener.front_end, aws_iam_role_policy_attachment.ecs_task_execution_role]
}