terraform {
  backend "s3" {
    bucket         = "YOUR_TERRAFORM_STATE_BUCKET_NAME_HERE" # Replace with your S3 bucket name
    key            = "eks-drift-demo/terraform.tfstate"    # Path to the state file in the bucket
    region         = "YOUR_AWS_REGION_HERE"                  # Replace with your AWS region (e.g., "us-west-2")
    dynamodb_table = "YOUR_TERRAFORM_LOCK_TABLE_NAME_HERE" # Replace with your DynamoDB table name
    encrypt        = true                                  # Recommended to encrypt the state file
  }
}
