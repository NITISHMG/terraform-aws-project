terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.16"
    }
  }
}
variable "vpc_cidr_block" {}        #defining variable here and in terraform.tfvars file#
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}
#vpc association#
resource "aws_vpc" "myapp-vpc" {  
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

#subnet  association#
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.myapp-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name : "${var.env_prefix}-subnet-1"
  }
}

#internet gateway association#
resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name : "${var.env_prefix}-igw"
  }
}
#routable association#
resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id  = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name : "${var.env_prefix}-rtb"
  }
}
#subnet association#
resource "aws_route_table_association" "aws-rtb-subnet" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.myapp-route-table.id
}
#security group port association#                                        # we can assin default sg which is created by aws# 
resource "aws_security_group" "myapp-sg" {                #resource "aws_default_security_group" "default-sg" {#
  name = "myapp-sg"                                       #vpc_id = aws_vpc.myapp-vpc.id # other than this every thing is same#
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
      from_port = 22  #can give range like from_port = 22 to_port = 800#
      to_port = 22
      protocol = "tcp"
      cidr_blocks = [var.my_ip]            # u can give coustom value like 172.2.5.66/32 #
  }
      ingress {
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]           
  }
  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
      from_port = 0        # outgoing traffic from server to outside#
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"] 
      prefix_list_ids = []        
  }
    tags = {
        Name: "${var.env_prefix}-sg"    # Name: "${var.env_prefix}-default-sg#
    }
}
    #creating ec2 instance#
data "aws_ami" "latest-amazon-linux-image" {
      most_recent = true
      owners = ["amazon"]  #This will be used when we create my AMI --- ower own amis#
      filter {
        name = "name"
        values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]  #amzn2-ami-kernel-5.10-hvm-2.0.20230612.0-x86_64-gp2#
      }
      filter {      #we can apply number of filters to get ower desired images#
        name = "virtualization-type"
        values = ["hvm"]
      }
}
output "aws_ami" {
  value = data.aws_ami.latest-amazon-linux-image
}
/*#creating ssh key ower self#
resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  #1st method #public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiGVZgyVq+40SiyZfvovwOfvGOAOiZjrf4Ej1R3pDhSjf+KkzK3tMvXXdg0pU8O3cnjPAtIh9ahEENTEN8IAsgg/vcr++omnvnWFtuksdb3dTSpB8OVRAqIB0EAzj2VS4LPETQ28BbFUFLjcJ6zcF3BijHIV+j4wDYNFg/M1zBYYNS94MFxxW0nfzcca9DkFxjKzT8mZZ4VbTd+v4iE6SK1VaijUPFlI5Nc6/9O1d7xWmDvqDbfl96g3aEmuXR1c+q7WEL4biVEB78Da2hOt5a5sVsnQGaKv/Lw7/LZFIiZJ/QMGlbHKB2z6VfBSQCR+XDJt4x+R0hbvs3tVoaFJE2dWMy36bf+7K20QIv52c0m6vv1tZI10Qx1gfUI8WjV4eE0qHd+X55Edtvpzwq0Uei+JPpZf0K9srwvxhwI2SM0HgzjjJQJ9WYGY06ABBriNrgEHa2l3uVcNc/Y4rNZ7hpRIqVUy/mmmer1q9hWYh41rcLkzgibjk9FhJQMzOH6Bl++ZUK4FwBKzJbyFhOplkDGcADP/n39M4q96uTvwyBu/fy7VBqZOd4jns3t5NB0Ic31ZTHAhgAjCzjA8oCJBMaYMXFzgQEAJAw/CLAA3p/JuzbWEn+tuz3munD3hxL9W/I8fJQqQ8uqnCEUV/v2umZUirSgNa6XE1Xvmf7Dx4mgQ== your_email@example.com"#
  #2nd method #public_key = var.my_public_id   #in this case we need to define variable#
  #public_key = file(var.public_key_location) #3rd method# giving file path to generate privet key pair#
}*/

#create aws isntance#
resource "aws_instance" "myapp-service" {
  #ami = "ami-012b9156f755804f5"#  or #       
  ami = data.aws_ami.latest-amazon-linux-image.id                         #if we want to change ami then u can use data#
  instance_type = var.instance_type

  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name = "dblinux"# directly give existing key name or create one as below#
 # key_name = aws_key_pair.ssh-key.key_name#
  
  user_data = file("userdata.sh")
      /*user_data = <<EOF 
                    #!/bin/bash
                    sudo yum update -y && sudo yum install docker -y
                    sudo systemctl start docker 
                    sudo usermod -aG docker ec2-user
                    docker run -p 8080:80 nginx
                EOF*/

   tags = {
    Name = "${var.env_prefix}-server"
  }

}











