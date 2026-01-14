module "network" {                                     # Call the network module
  source = "./modules/network"                          # Path to the network module
}

module "security" {                                   # Call the security module
  source = "./modules/security"                         # Path to security module
  vpc_id = module.network.vpc_id                        # Pass VPC ID from network output
}

module "eks" {                                        # Call the EKS module
  source       = "./modules/eks"                        # Path to EKS module
  cluster_name = "self-healing-eks"                     # Name of the EKS cluster
  vpc_id       = module.network.vpc_id                  # Pass VPC ID to EKS
  subnet_ids   = module.network.public_subnet_ids      # Pass subnet IDs to EKS
}
