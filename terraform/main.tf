provider "aws" {
  region = var.aws_region
}

# Locals or data sources could be placed here if needed at the root level.
# For instance, if you need to get the current AWS Account ID or Caller Identity:
# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}
