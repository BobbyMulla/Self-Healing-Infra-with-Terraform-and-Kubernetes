variable "vpc_id" {                                   # Declare an input variable named vpc_id
  description = "VPC where the EKS cluster will be created" # Human-readable explanation of why this variable exists
  type        = string                                # The VPC ID is always a string (e.g., vpc-0a12bc...)
}

variable "subnet_ids" {                               # Declare an input variable named subnet_ids
  description = "Subnets where EKS worker nodes will run"   # Explains that worker nodes need subnets
  type        = list(string)                           # This must be a list of subnet IDs (multiple allowed)
}

variable "cluster_name" {                             # Declare an input variable for naming the cluster
  description = "Name of the EKS cluster"              # Used for identification in AWS console and CLI
  type        = string                                 # Cluster name is text
}
