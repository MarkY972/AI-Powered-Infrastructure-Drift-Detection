variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name for the EKS cluster and associated resources"
  type        = string
  default     = "my-eks-drift-demo"
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes in the EKS node group"
  type        = number
  default     = 3
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_disk_size" {
  description = "Disk size (in GB) for EKS worker nodes"
  type        = number
  default     = 20
}

variable "ec2_ssh_key_name" {
  description = "Name of the EC2 key pair to allow SSH access to nodes (optional). If not provided, SSH access might be disabled or use instance profiles."
  type        = string
  default     = "" # Set to your key pair name if you need SSH access
}
