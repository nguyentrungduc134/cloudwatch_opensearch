provider "aws" {
  region = var.region
}

###################
# lambda role
###################
resource "aws_iam_role" "lambda_logs" {
  name               = "lambda_logs"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "iam_role_policy_lambda" {
  name   = "lambda_logs"
  role   = aws_iam_role.lambda_logs.id
  policy = data.aws_iam_policy_document.lambda_logs.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs_vpc_access" {
  role       = aws_iam_role.lambda_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
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

data "aws_iam_policy_document" "lambda_logs" {
  statement {
    actions   = [
      "es:*"]
    effect    = "Allow"
    resources = [
      "*"]
  }

}
#####################################
# deploy our lambda function
# Note : the lambda src is the official AWS source
# we only add the elasticSearh domain in environment variable
# to be more generic.
#####################################
resource "aws_security_group" "https" {
  name        = "https"
  description = "Allow HTTPS inbound traffic"
  vpc_id      = var.vpc_id  # Replace with your VPC ID variable

  ingress {
    description      = "Allow HTTPS inbound from 10.0.0.0/16"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_https_security_group"
  }
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.12.0"

  # set global attributs
  function_name = format("lbd-%s-%s", var.environment, var.function_name)
  description   = "Stream Logs on ElasticSearch"
  publish       = true
  handler       = "index.handler"
  source_path = [
    "${path.module}/lambda-src/index.js",
  ]
  vpc_subnet_ids                     = var.subnet_ids
  vpc_security_group_ids             = [resource.aws_security_group.https.id]
  attach_network_policy              = true
  memory_size = "128"
  runtime     = "nodejs18.x"
  timeout     = 900

  # attach a cloudWatch log group
  create_role = false
  lambda_role = resource.aws_iam_role.lambda_logs.arn

  # add environment variables
  environment_variables = {
    ELASTICSEARCH_ENDPOINT = var.es_domain_endpoint
  }

  # put tags on lambda function
  tags = var.tags
}

##############################
# Allow CloudWatch Logs to invoke Lambda function
##############################
data "aws_cloudwatch_log_group" "logs" {
  name = var.cloudwatch_log_name
}

resource "aws_lambda_permission" "cloudwatch-logs-invoke-elasticsearch-lambda" {
  statement_id   = format("rp-%s-%s-logs-to-es", var.environment, var.log_name)
  action         = "lambda:InvokeFunction"
  function_name  = module.lambda.lambda_function_arn
  principal      = "logs.amazonaws.com"
  source_arn     = format("%s:*", data.aws_cloudwatch_log_group.logs.arn)
}


###########################################
# Deploy a subscription filter on  Cloudwatch Logs
###########################################
resource "aws_cloudwatch_log_subscription_filter" "log_cw_subscription" {
  name            = format("subsr-%s-%s-logs", var.environment, var.log_name)
  log_group_name  = var.cloudwatch_log_name
  filter_pattern  = var.filter_pattern
  destination_arn = module.lambda.lambda_function_arn
}
