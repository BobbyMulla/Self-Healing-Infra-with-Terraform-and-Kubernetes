#This is the private network where everything will live
resource "aws_vpc" "this" {                     # Create a VPC (private network in AWS)
  cidr_block = "10.0.0.0/16"                     # Define IP range for the entire VPC

  tags = {                                      # Add tags for identification in AWS
    Name = "self-healing-vpc"                   # Name shown in AWS console
  }
}
#Anything launched here can talk to the internet
resource "aws_subnet" "public_1" {                # Create a subnet inside the VPC
  vpc_id     = aws_vpc.this.id                  # Attach this subnet to the VPC
  cidr_block = "10.0.1.0/24"                    # IP range for this subnet
  availability_zone = "ap-south-1a"             # Place subnet in a specific AZ
  map_public_ip_on_launch = true                # Automatically assign public IPs to resources
                                                # launched in this subnet
  tags = {                                      # Tags for easier identification
    Name = "sf-public-subnet-1a"                   # Name shown in AWS console
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "sf-public-subnet-1b"
  }
}

#This is the door from my VPC to the internet
resource "aws_internet_gateway" "this" {         # Create an Internet Gateway
  vpc_id = aws_vpc.this.id                      # Attach the Internet Gateway to the VPC

  tags = {                                      # Tags for identification
    Name = "self-healing-igw"                   # Name shown in AWS console
  }
}

#If traffic wants to go anywhere, send it to the internet gateway
resource "aws_route_table" "public" {            # Create a route table
  vpc_id = aws_vpc.this.id                      # Attach route table to the VPC

  route {                                      # Define a routing rule
    cidr_block = "0.0.0.0/0"                    # Match all outbound traffic
    gateway_id = aws_internet_gateway.this.id   # Send it to the Internet Gateway
  }

  tags = {                                     # Tags for identification
    Name = "sf-public-rt"                       # Name shown in AWS console
  }
}

#Apply these internet rules to this subnet
resource "aws_route_table_association" "public_1" {     # Associate a subnet with a route table
  subnet_id      = aws_subnet.public_1.id          # The subnet that needs routing rules
  route_table_id = aws_route_table.public.id     # The route table to apply to the subnet
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
#VPC → private network boundary
#Subnet → smaller network inside VPC
#Internet Gateway → allows internet access
#Route Table → decides where traffic goes
#Association → applies rules to subnet
