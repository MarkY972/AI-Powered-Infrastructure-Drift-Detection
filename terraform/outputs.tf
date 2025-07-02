output "cluster_endpoint" {
  description = "Endpoint for your EKS Kubernetes API server."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name."
  value       = aws_eks_cluster.main.name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_group_role_arn" {
  description = "IAM role ARN for the EKS node group."
  value       = aws_iam_role.eks_node_group_role.arn
}

output "sns_topic_drift_notifications_arn" {
  description = "ARN of the SNS topic for drift notifications."
  value       = aws_sns_topic.drift_notifications.arn
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
