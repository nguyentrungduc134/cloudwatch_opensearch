# Terraform Lambda Logging to Elasticsearch Setup

## Overview
This Terraform configuration deploys an AWS Lambda function that streams CloudWatch Logs to an Elasticsearch domain. The Lambda function has necessary IAM roles and security group settings to operate securely within a VPC. Below are the components involved in this setup.

## AWS Provider Configuration
The `provider` block sets up the AWS provider and uses the `region` variable to configure the region where the resources will be deployed.

```hcl
provider "aws" {
  region = var.region
}
```

## Components

### IAM Role for Lambda
The Lambda function requires an IAM role with two policies:
1. **AssumeRole Policy:** Allows the Lambda function to assume the IAM role.
2. **Lambda Logs Policy:** Grants permission for the Lambda function to interact with Amazon Elasticsearch.

```hcl
resource "aws_iam_role" "lambda_logs" {
  name               = "lambda_logs"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "iam_role_policy_lambda" {
  name   = "lambda_logs"
  role   = aws_iam_role.lambda_logs.id
  policy = data.aws_iam_policy_document.lambda_logs.json
}
```

The following data blocks define the policies:
```hcl
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
    actions   = ["es:*"]
    effect    = "Allow"
    resources = ["*"]
  }
}
```

### Attach AWSLambdaVPCAccessExecutionRole Policy
This policy is attached to allow the Lambda function to access resources within a VPC.

```hcl
resource "aws_iam_role_policy_attachment" "lambda_logs_vpc_access" {
  role       = aws_iam_role.lambda_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
```

### Security Group for HTTPS Traffic
A security group is created to allow inbound HTTPS traffic (port 443) from a specific CIDR block.

```hcl
resource "aws_security_group" "https" {
  name        = "https"
  description = "Allow HTTPS inbound traffic"
  vpc_id      = var.vpc_id

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
```

### Lambda Module
The Lambda function is deployed using the official Terraform AWS Lambda module. It includes environment variables for connecting to an Elasticsearch domain and is associated with the security group created above.

```hcl
module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.12.0"

  function_name = format("lbd-%s-%s", var.environment, var.function_name)
  description   = "Stream Logs on ElasticSearch"
  publish       = true
  handler       = "index.handler"
  source_path = [
    "${path.module}/lambda-src/index.js",
  ]
  vpc_subnet_ids = var.subnet_ids
  vpc_security_group_ids = [aws_security_group.https.id]
  attach_network_policy = true
  memory_size = "128"
  runtime     = "nodejs18.x"
  timeout     = 900

  create_role = false
  lambda_role = aws_iam_role.lambda_logs.arn

  environment_variables = {
    ELASTICSEARCH_ENDPOINT = var.es_domain_endpoint
  }

  tags = var.tags
}
```

### CloudWatch Log Permissions for Lambda Invocation
This resource grants CloudWatch Logs permission to invoke the Lambda function.

```hcl
resource "aws_lambda_permission" "cloudwatch-logs-invoke-elasticsearch-lambda" {
  statement_id   = format("rp-%s-%s-logs-to-es", var.environment, var.log_name)
  action         = "lambda:InvokeFunction"
  function_name  = module.lambda.lambda_function_arn
  principal      = "logs.amazonaws.com"
  source_arn     = format("%s:*", data.aws_cloudwatch_log_group.logs.arn)
}
```

### CloudWatch Log Subscription Filter
A CloudWatch log subscription filter is created to forward RDS logs to the Lambda function for processing.

```hcl
resource "aws_cloudwatch_log_subscription_filter" "log_cw_subscription" {
  name            = format("subsr-%s-%s-logs", var.environment, var.log_name)
  log_group_name  = var.cloudwatch_log_name
  filter_pattern  = var.filter_pattern
  destination_arn = module.lambda.lambda_function_arn
}
```

## Variables

Ensure that you provide the following variables either through a `.tfvars` file or directly in your Terraform commands:

- `region`
- `vpc_id`
- `subnet_ids`
- `es_domain_endpoint`
- `cloudwatch_log_name`
- `log_name`
- `environment`
- `function_name`
- `filter_pattern`

## Applying the Configuration
To apply the Terraform configuration:

```bash
terraform init
terraform apply -var-file="your_variables.tfvars"
```

This will set up the IAM roles, Lambda function, CloudWatch permissions, and the necessary resources to stream logs to Elasticsearch.

## Additional Notes
- Ensure your Lambda source code (`index.js`) is placed in the specified path.
- Replace placeholder variables like `var.vpc_id`, `var.subnet_ids`, and others with your actual values.
