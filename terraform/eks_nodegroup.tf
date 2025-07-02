# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id] # Best practice: run nodes in private subnets

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  instance_types = [var.node_instance_type]
  disk_size      = var.node_disk_size

  remote_access {
    ec2_ssh_key = var.ec2_ssh_key_name != "" ? var.ec2_ssh_key_name : null # Optional: specify an SSH key for node access
    # If you create a specific SG for SSH, add it here:
    # source_security_group_ids = [aws_security_group.eks_node_ssh_sg.id]
  }

  launch_template {
      name_prefix = "${var.cluster_name}-lt-" # Changed from name to name_prefix
      tags = {
          "Name" = "${var.cluster_name}-node"
      }
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_group_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.eks_node_group_AmazonEKS_CNI_Policy,
  ]

  tags = {
    Name = "${var.cluster_name}-node-group"
  }
}
