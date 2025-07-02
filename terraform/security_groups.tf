# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# Security Group for EKS Node Group
resource "aws_security_group" "eks_node_group_sg" {
  name        = "${var.cluster_name}-node-group-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound traffic from the cluster control plane
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }

  ingress {
    from_port = 10250 # Kubelet API
    to_port = 10250
    protocol = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }

  # Allow inbound SSH (optional, for bastion or direct access - restrict source if used)
  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["YOUR_IP_ADDRESS/32"] # Replace with your IP or remove if not needed
  # }

  tags = {
    Name                                        = "${var.cluster_name}-node-group-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Allow worker nodes to communicate with the cluster control plane
resource "aws_security_group_rule" "cluster_to_node_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  security_group_id        = aws_security_group.eks_node_group_sg.id
}

resource "aws_security_group_rule" "node_to_cluster_https" {
  type                          = "egress" # Egress from node to cluster
  from_port                     = 443
  to_port                       = 443
  protocol                      = "tcp"
  destination_security_group_id = aws_security_group.eks_cluster_sg.id # Traffic destination is cluster SG
  security_group_id             = aws_security_group.eks_node_group_sg.id # Rule applied to node SG
}
