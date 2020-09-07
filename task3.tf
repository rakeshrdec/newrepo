provider "aws" {
 region = "ap-south-1"
 profile = "default"
}

# Create a VPC
resource "aws_vpc" "task3vpc" {
  cidr_block = "192.168.0.0/16"
}


#CREATING SUBNETS

resource "aws_subnet" "subnet-1a" {
  vpc_id     = aws_vpc.task3vpc.id
  availability_zone = "ap-south-1a"
  cidr_block = "192.168.0.0/24"
  map_public_ip_on_launch = true
tags = {
  Name = "public-subnet-1a"
    }
  }


resource "aws_subnet" "subnet-1b" {
  vpc_id     = aws_vpc.task3vpc.id
  availability_zone = "ap-south-1b"
  cidr_block = "192.168.1.0/24"
   map_public_ip_on_launch = false
tags = {
  Name = "private-subnet-1b"
     }
   }


#CREATING INTERNET GATEWAY

resource "aws_internet_gateway" "task3gateway" {
  vpc_id = aws_vpc.task3vpc.id
  tags = {
    Name = "task3gateway"
  }
}

#CREATING ROUTING TABLE

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.task3vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task3gateway.id
  }
  tags = {
    Name = "my-routes-for-outside"
  }
}

#ASSOCIATING ROUTING TABLE WITH PUBLIC SUBNET

resource "aws_route_table_association" "route_association" {
  subnet_id      = aws_subnet.subnet-1a.id
  route_table_id = aws_route_table.route.id
}

#CREATING SECURITY GROUP FOR WORDPRESS

resource "aws_security_group" "wordpress-sg" {
  depends_on = [aws_vpc.task3vpc]
  vpc_id      = aws_vpc.task3vpc.id
      ingress {
    description = "Creating SSH security group"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "Creating HTTP security group"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "Creating HTTPS security group"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
 }
 ingress {
    description = "Creating MySQL port"
    from_port   = 3306
    to_port     = 3306
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
 Name = "wordpress-sg"
}
}


#CREATING SECURITY GROUP FOR MYSQL

 resource "aws_security_group" "mysql-sg" {
 depends_on = [aws_vpc.task3vpc]
 vpc_id      = aws_vpc.task3vpc.id
   
    ingress {
    description = "Creating MySQL port"
    from_port   = 3306
    to_port     = 3306
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
 Name = "mysql-sg"

}
}


#LAUNCHING WORDPRESS EC2 INSTANCE

resource "aws_instance" "wordpress" {
  ami           = "ami-0151caa79dbe9bd27"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet-1a.id
  vpc_security_group_ids = [ aws_security_group.wordpress-sg.id ] 
   key_name = "key11" 
  tags = {
    Name = "Wordpress_instance"
  }
}


#LAUNCHING MYSQL DATABASE EC2 INSTANCE

resource "aws_instance" "mysql" {
  ami           = "ami-76166b19"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet-1b.id
  vpc_security_group_ids = [ aws_security_group.mysql-sg.id ] 
  key_name = "key11" 
  tags = {
    Name = "mysql"
  }
}


#FOR SHOWING OUTPUT

output "IP_Address" {
value = aws_instance.wordpress.public_ip
}

output "VPC_ID" {
value = aws_vpc.task3vpc.id
}
