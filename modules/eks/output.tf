output "cluster_name" {
  value = aws_eks_cluster.this.name                    # Used to configure kubectl
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint                # Kubernetes API endpoint
}
