data "archive_file" "scale_down_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/scale_down.py"
  output_path = "${path.module}/lambda/scale_down.zip"
}

# Lambda IAM

resource "aws_iam_role" "scale_down_lambda" {
  name = "${var.cluster_name}-scale-down-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.scale_down_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_eks_scale" {
  name = "${var.cluster_name}-eks-scale-down"
  role = aws_iam_role.scale_down_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:UpdateNodegroupConfig"
        ]

        Resource = "*"
      }
    ]
  })
}

# Lambda

resource "aws_lambda_function" "scale_down_node_group" {
  function_name = "${var.cluster_name}-scale-down-node-group"

  filename         = data.archive_file.scale_down_lambda.output_path
  source_code_hash = data.archive_file.scale_down_lambda.output_base64sha256

  role = aws_iam_role.scale_down_lambda.arn

  handler = "scale_down.lambda_handler"
  runtime = "python3.13"

  environment {
    variables = {
      CLUSTER_NAME = module.eks.cluster_name

      NODE_GROUP_NAME = split(
        ":",
        module.eks.eks_managed_node_groups["gpu_spot"].node_group_id
      )[1]
    }
  }

  tags = {
    Environment = "lab"
    Terraform   = "true"
  }
}

# EventBridge Scheduler IAM

resource "aws_iam_role" "scheduler" {
  name = "${var.cluster_name}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "scheduler.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "${var.cluster_name}-invoke-scale-down"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "lambda:InvokeFunction"
        ]

        Resource = aws_lambda_function.scale_down_node_group.arn
      }
    ]
  })
}

# EventBridge Scheduler

resource "aws_scheduler_schedule" "scale_down_node_group" {
  name = "${var.cluster_name}-scale-down-23h"

  description = "Scales EKS GPU node group to zero every day at 23:00"

  schedule_expression          = "cron(0 23 * * ? *)"
  schedule_expression_timezone = "America/Sao_Paulo"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.scale_down_node_group.arn
    role_arn = aws_iam_role.scheduler.arn

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
}