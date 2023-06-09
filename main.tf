#Create a custom vpc
resource "aws_vpc" "customvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "customVPC"
  }
}

#create public subnet
resource "aws_subnet" "publicsubnet" {
  vpc_id                  = aws_vpc.customvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.igw]

  tags = {
    Name = "custompublicsubnet"
  }
}

#create custom route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.customvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "customroutetable"
  }
}

#create route table association to public subnet
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.public_rt.id
  depends_on = [
    aws_subnet.publicsubnet,
    aws_route_table.public_rt
  ]
}

#create internet gateway and update the route table 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.customvpc.id

  tags = {
    Name = "internetGW"
  }
}

#create key pair
resource "aws_key_pair" "tf-key-pair" {
key_name = "tf-key-pair"
public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
algorithm = "RSA"
rsa_bits  = 4096
}
resource "local_file" "tf-key" {
content  = tls_private_key.rsa.private_key_pem
filename = "tf-key-pair"
}

#create custom security group
resource "aws_security_group" "allow_traffic" {
  name        = "allow_web_traffic"
  description = "Allow inbound traffic to communicate to internet"
  vpc_id      = aws_vpc.customvpc.id

  ingress {
    description = "Allow traffic from https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow traffic from http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "custom_SG"
  }
}

#create an ec2 instance and install apache web server
resource "aws_instance" "web_server" {
  ami                         = "ami-0715c1897453cabd1"
  instance_type               = "t2.micro"
  availability_zone           = "us-east-1a"
  key_name                    = "tf-key-pair"
  subnet_id                   = aws_subnet.publicsubnet.id
  associate_public_ip_address = true
  security_groups             = [aws_security_group.allow_traffic.id]
  user_data                   = <<-EOF
                                #!/bin/bash
                                sudo apt-get update -y
                                sudo apt-get install -y httpd
                                sudo systemctl start httpd
                                echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
                                EOF

  tags = {
    Name = "web_server"
  }
}

output "public_ip" {
  value       = aws_instance.web_server.public_ip
  sensitive   = false
  description = "Print out my public IP Address"
  depends_on  = [aws_instance.web_server]
}

