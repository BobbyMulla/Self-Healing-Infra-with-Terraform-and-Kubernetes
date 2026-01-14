provider "aws" {                    # Tell Terraform which cloud provider to use
  region = "ap-south-1"              # Specify the AWS region where resources will be created
}
#Terraform, when I ask you to create resources,
#do it in AWS, and do it in the ap-south-1 (Mumbai) region