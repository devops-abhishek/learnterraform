
/* Cloud Provider Details */
provider "aws" {
  region = "ap-south-1"
}

/*Create a VPC*/
resource "aws_vpc" "Development-VPC" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
      Name = "Development-VPC"
  }
}

#Create IGW and Attach it to VPC
resource "aws_internet_gateway" "Development-IGW" {
    vpc_id = aws_vpc.Development-VPC.id
    tags = {
      "Name" = "Development-IGW"
    }
    depends_on = [
      aws_vpc.Development-VPC
    ]
}

#Create EIP for NAT Gateway
resource "aws_eip" "Development-EIP-NAT" {
    vpc = true
    tags = {
      "Name" = "Development-EIP-NAT"
    }
    depends_on = [
      aws_internet_gateway.Development-IGW
    ]
}

#Create NAT Gateway
resource "aws_nat_gateway" "Development-NAT" {
    allocation_id = aws_eip.Development-EIP-NAT.id
    subnet_id = aws_subnet.Development-Subnet-Private.id
    tags = {
      "Name" = "Development-NAT"
    }
}

#Create Public Subnet
resource "aws_subnet" "Development-Subnet-Public" {
  vpc_id = aws_vpc.Development-VPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
      Name = "Development-Subnet-Public"
  }
}
#Create Private Subnet
resource "aws_subnet" "Development-Subnet-Private" {
  vpc_id = aws_vpc.Development-VPC.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = false
  tags = {
      Name = "Development-Subnet-Private"
  }
}

#Create Public Route Table
resource "aws_route_table" "Development-Route-Table-Public" {
    vpc_id = aws_vpc.Development-VPC.id
    tags = {
      "Name" = "Development-Route-Public"
    }
}

#Create Private Route Table
resource "aws_route_table" "Development-Route-Table-Private" {
    vpc_id = aws_vpc.Development-VPC.id
    tags = {
      "Name" = "Development-Route-Private"
    }
}

resource "aws_route" "Development-Route-Public" {
    route_table_id = aws_route_table.Development-Route-Table-Public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Development-IGW.id
    depends_on = [
      aws_internet_gateway.Development-IGW
    ]
}

resource "aws_route" "Development-Route-Private" {
    route_table_id = aws_route_table.Development-Route-Table-Private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.Development-NAT.id
    depends_on = [
      aws_nat_gateway.Development-NAT
    ]
}

resource "aws_route_table_association" "Development-Route-Table-Association-Public" {
  subnet_id      = aws_subnet.Development-Subnet-Public.id
  route_table_id = aws_route_table.Development-Route-Table-Public.id
}

resource "aws_route_table_association" "Development-Route-Table-Association-Private" {
  subnet_id     = aws_subnet.Development-Subnet-Private.id
  route_table_id = aws_route_table.Development-Route-Table-Private.id
}

resource "aws_security_group" "Development-Public-SG" {
  name        = "Development-Public-SG"
  description = "Allow 22 inbound traffic"
  vpc_id      = aws_vpc.Development-VPC.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Development-Public-SG"
  }
}

output "ip" {
      value = "aws_security_group.Development-Public-SG.cidr_block"
}

resource "aws_security_group" "Development-Private-SG" {
  name        = "Development-Private-SG"
  description = "Allow 22 inbound traffic"
  vpc_id      = aws_vpc.Development-VPC.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["10.0.1.0/24"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Development-Private-SG"
  }
}

resource "aws_instance" "Development-EC2-Public" {
    ami = "ami-0af25d0df86db00c1"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.Development-Public-SG.id]
    subnet_id = aws_subnet.Development-Subnet-Public.id
    key_name = "aws"
    tags = {
      "Name" = "Development-EC2-Public"
    }
}

resource "aws_instance" "Development-EC2-Private" {
    ami = "ami-0af25d0df86db00c1"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.Development-Private-SG.id]
    subnet_id = aws_subnet.Development-Subnet-Private.id
    key_name = "aws"
    tags = {
      "Name" = "Development-EC2-Private"
    }
}
