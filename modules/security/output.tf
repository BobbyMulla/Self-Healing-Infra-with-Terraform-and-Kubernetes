output "security_group_id" {                          # Declare an output variable named security_group_id
  value = aws_security_group.this.id                  # Export the ID of the security group we created
}
#I created a security group.
#If anyone else needs it, here is its ID