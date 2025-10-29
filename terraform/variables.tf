variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = "us-west-2"
}

variable "terraform_lambda_layer_arn" {
  description = "The ARN of the public Lambda Layer containing the Terraform binary."
  type        = string
  # This is a publicly available layer. For production, you might want to build your own.
  default     = "arn:aws:lambda:us-west-2:831357218693:layer:terraform-1-1-9:1"
}

