resource "aws_security_group" "this" {          # Create a security group (acts like a firewall)
  name        = "self-healing-sg"                # Name of the security group in AWS
  description = "Allow SSH and HTTP"             # Human-readable description of what this SG allows
  vpc_id      = var.vpc_id                       # Attach this security group to the given VPC
                                                 # (passed in from the network module via main.tf)

  ingress {                                     # Inbound rule block (traffic coming INTO the resource)
    from_port   = 22                             # Starting port number (SSH)
    to_port     = 22                             # Ending port number (same as from_port = single port)
    protocol    = "tcp"                          # Use TCP protocol (SSH works over TCP)
    cidr_blocks = ["0.0.0.0/0"]                  # Allow traffic from ANY IP address on the internet
  }

  ingress {                                     # Another inbound rule block
    from_port   = 80                             # Starting port number (HTTP)
    to_port     = 80                             # Ending port number (single port)
    protocol    = "tcp"                          # Use TCP protocol (HTTP uses TCP)
    cidr_blocks = ["0.0.0.0/0"]                  # Allow HTTP access from anywhere
  }

  egress {                                      # Outbound rule block (traffic going OUT)
    from_port   = 0                              # Starting port (0 means all ports)
    to_port     = 0                              # Ending port (0 means all ports)
    protocol    = "-1"                           # -1 means allow ALL protocols
    cidr_blocks = ["0.0.0.0/0"]                  # Allow outbound traffic to anywhere
  }

  tags = {                                      # Tags help identify the resource in AWS
    Name = "self-healing-sg"                     # Name tag shown in AWS console
  }
}

#It allows SSH for administration, HTTP for application access, and unrestricted outbound traffic