#######################################
# Global Variables
#######################################
variable "region" {
  type        = string
  description = "The AWS Region"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "The Environment label"
  default     = "test"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags"
  default     = {}
}

#######################################
# Variables for lambda deployment
#######################################
variable "function_name" {
  type        = string
  description = "The lambda function name. Format lbd-{environment}-{function_name}"
  default     = "stream-logs"
}

variable "log_name" {
  type        = string
  description = "The Identifier for which we want stream logs"
}

variable "cloudwatch_log_name" {
  type        = string
  description = "The Name of the Cloudwatch Log for which we want stream logs"
}

variable "es_domain_endpoint" {
  type        = string
  description = "The ElasticSearch Domain endpoint"
}

variable "filter_pattern" {
  type        = string
  description = "The pattern used to filter logs"
  default     = "info"
}

variable "vpc_id" {
  description = "The ID of the VPC where lambda will be created (opensearch)"
  type        = string
}

variable "subnet_ids" {
  description = "A list of Subnet IDs where lambda will be deployed"
  type        = list(string)
}

