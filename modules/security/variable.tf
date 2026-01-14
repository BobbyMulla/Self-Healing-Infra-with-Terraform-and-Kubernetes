variable "vpc_id" {                                   # Declare an input variable named vpc_id
  description = "The ID of the VPC where the security group will be created"
                                                      # Explains WHY this variable is needed
  type        = string                                # VPC IDs are always strings (e.g., vpc-0abc123)
}
#I am the security module.
#I cannot create a security group unless someone tells me which VPC to put it in