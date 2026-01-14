output "vpc_id" {                      # Declare an output variable named vpc_id
  value = aws_vpc.this.id              # Export the ID of the VPC created in this module
}

output "public_subnet_ids" {              # Declare an output variable named public_subnet_id
  value = [aws_subnet.public_1.id,        # Export the ID of the public subnet
  aws_subnet.public_2.id         # Export the ID of the public subnet
  ]
}

#Here are the things I created that other modules might need