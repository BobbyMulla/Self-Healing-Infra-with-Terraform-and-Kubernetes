resource "aws_iam_role" "eks_cluster_role" {           # Create an IAM role resource for EKS itself
  name = "${var.cluster_name}-eks-cluster-role"        # Name the role using the cluster name for clarity

  assume_role_policy = jsonencode({                    # Policy that defines WHO can assume this role
    Version = "2012-10-17"                              # IAM policy language version
    Statement = [{                                     # A list of permission statements
      Effect = "Allow"                                 # Allow the action below
      Principal = {                                    # Define which AWS service can assume this role
        Service = "eks.amazonaws.com"                  # Only the EKS service can assume this role
      }
      Action = "sts:AssumeRole"                        # Allow EKS to assume this role via STS
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" { # Attach a policy to the EKS role
  role       = aws_iam_role.eks_cluster_role.name       # Specify which IAM role gets the policy
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" # AWS-managed policy for EKS control plane
}

resource "aws_eks_cluster" "this" {                    # Create an EKS cluster resource
  name     = var.cluster_name                           # Name of the EKS cluster
  role_arn = aws_iam_role.eks_cluster_role.arn          # IAM role that EKS will assume

  vpc_config {                                         # Networking configuration for the cluster
    subnet_ids = var.subnet_ids                         # Subnets used for Kubernetes networking
  }

  depends_on = [                                       # Explicit dependency list
    aws_iam_role_policy_attachment.eks_cluster_policy  # Ensure IAM policy is attached before cluster creation
  ]
}

resource "aws_iam_role" "eks_node_role" {               # Create IAM role for worker node EC2 instances
  name = "${var.cluster_name}-eks-node-role"            # Name role clearly for identification

  assume_role_policy = jsonencode({                     # Define who can assume this role
    Version = "2012-10-17"                               # IAM policy language version
    Statement = [{
      Effect = "Allow"                                  # Allow the action
      Principal = {
        Service = "ec2.amazonaws.com"                   # EC2 instances can assume this role
      }
      Action = "sts:AssumeRole"                         # Allow EC2 to assume the role
    }]
  })
}
# Allows EC2 worker nodes to join the EKS cluster and talk to the control plane
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" { # Attach worker node policy
  role       = aws_iam_role.eks_node_role.name          # Attach to the EC2 node role
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" # Allows node to join EKS
}
# Allows Kubernetes pods to get IP addresses and communicate over the VPC network
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {         # Attach networking policy
  role       = aws_iam_role.eks_node_role.name          # Same EC2 role
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" # Allows pod networking (ENIs)
}
# Allows pulling images from ECR repositories
resource "aws_iam_role_policy_attachment" "eks_registry_policy" {    # Attach ECR read-only policy
  role       = aws_iam_role.eks_node_role.name          # Same EC2 role
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" # Allows pulling images
}

resource "aws_eks_node_group" "this" {                  # Create a managed EKS node group
  cluster_name    = aws_eks_cluster.this.name           # Attach node group to this EKS cluster
  node_group_name = "${var.cluster_name}-node-group"    # Name the node group
  node_role_arn  = aws_iam_role.eks_node_role.arn       # IAM role for EC2 worker nodes
  subnet_ids     = var.subnet_ids                       # Subnets where EC2 nodes will launch

  scaling_config {                                     # Node scaling configuration
    desired_size = 1                                   # Number of nodes to run normally
    max_size     = 1                                   # Maximum nodes allowed
    min_size     = 1                                   # Minimum nodes allowed
  }

  instance_types = ["t3.small"]                         # EC2 instance type for worker nodes
}
