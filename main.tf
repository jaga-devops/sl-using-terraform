provider "aws" {
      region     = "${var.region}"
      access_key = "${var.access_key}"
      secret_key = "${var.secret_key}"
}

#CREATING 1 VPC
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "OWN-VPC"
  }
}

#CREATE PUBLIC SUBNET1
resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet1_cidr_block
  map_public_ip_on_launch = true #THIS WILL ENABLE PUBLIC IP OF INSTANCE WHICH WILL BECREATED IN PUBLIC SUBNET
  tags = {
    Name = "PUBLIC-SUBNET-1"
  }
}

#CREATE PRIVATE SUBNET1
resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet1_cidr_block

  tags = {
    Name = "PRIVATE-SUBNET-1"
  }
}

#CREATE INTERNET GATEWAY
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "OWN-main"
  }
}

#CREATING ELASTIC IP WHICH WILL BW ASSOCIATED WITH NAT GATEWAY
resource "aws_eip" "EIP1" {
  tags = {
    Env = "dev"
  }
}

#CREATE NAT GATEWAY IN PUBLIC SUBNET 
resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.EIP1.id #NATGATEWAY SHOULD HAVE ELASTIC IP
  subnet_id     = aws_subnet.public1.id #VVIMP IT's ALWAYS RECOMMENDED THAT NAT GATEWAY SHOULD BE CREATED IN PUBLIC SUBNET

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

#CREATING PUBLIC ROUTE TABLE
resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "PUBLIC-RT-1"
  }
}

#CREATING ROUTE FOR PUBLIC ROUTE TABLE
resource "aws_route" "public" {
  route_table_id         = aws_route_table.publicRT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

#SUBNET ASSOCIATE WITH ROUTE OF PUBLIC ROUTE TABLE
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.publicRT.id
}

#CREATING PRIVATE ROUTE TABLE
resource "aws_route_table" "privateRT" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "PRIVATE-RT-1"
  }
}

#CREATING ROUTE FOR PRIVATE ROUTE TABLE
resource "aws_route" "private" {
  route_table_id         = aws_route_table.privateRT.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id             = aws_nat_gateway.example.id
}

#SUBNET ASSOCIATE WITH ROUTE OF PRIVATE  ROUTE TABLE
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.privateRT.id
}

#CREATING VPN-SG

resource "aws_security_group" "VPN-SG" {
  name        = "VPN_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 19909
    to_port          = 19909
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 27017
    to_port          = 27017
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "VPN SECURITY GROUP"
  }
}
resource "aws_instance" "tes" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.VPN-SG.id]
  tags = {
    Name = "VPN"
  }
}

#CREATE BASTION HOST SG

resource "aws_security_group" "BASTION-HOST-SG" {
  name        = "BASTION-HOST-SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "BASTION HOST SECURITY GROUP"
  }
}


#ADDING INBOUND RULE FOR BASTION HOST SECURITY GROUP
resource "aws_security_group_rule" "BASTION-HOST-SG-RULE" {
  security_group_id = aws_security_group.BASTION-HOST-SG.id
  type              = "ingress"
  from_port        = 22
  to_port          = 22
  protocol         = "tcp"
  source_security_group_id = aws_security_group.VPN-SG.id
}

#ADDING OUTBOUND RULE FOR BASTION HOST SECURITY GROUP
resource "aws_security_group_rule" "BASTION-HOST-SG-OUTBOUND-RULE" {
  security_group_id = aws_security_group.BASTION-HOST-SG.id
  type              = "egress"
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
}

#CREATE BASTION HOST

resource "aws_instance" "bastion_host_server" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.BASTION-HOST-SG.id]
  tags = {
    Name = "BASTION HOST"
  }
}

#CREATING PROD ELEVATE NGINX SG
resource "aws_security_group" "PROD-ELEVATE-NGINX-SG" {
  name        = "PROD_ELEVATE_NGINX_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PROD ELEVATE NGINX SECURITY GROUP"
  }
}

#CREATE PROD ELEVATE NGINX SERVER
resource "aws_instance" "PROD-ELEVATE-NGINX" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.PROD-ELEVATE-NGINX-SG.id]
  tags = {
    Name = "PROD ELEVATE NGINX"
  }
}

#CREATING HASHICROP VAULT SG
resource "aws_security_group" "HASHICROP-VAULT-SG" {
  name        = "HASHICROP_VAULT_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 8200
    to_port          = 8200
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "HASHICROP VAULT SECURITY GROUP"
  }
}

#CREATE HASHICROP VAULT SERVER

resource "aws_instance" "HASHICROP-VAULT" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.HASHICROP-VAULT-SG.id]
  tags = {
    Name = "HASHICROP VAULT"
  }
}

#CREATING PROD ELEVATE ANALYTICS SG
resource "aws_security_group" "PROD-ELEVATE-ANALYTICS-SG" {
  name        = "PROD_ELEVATE_ANALYTICS_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
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
  }

  tags = {
    Name = "PRO ELEVATE ANALYTICS SECURITY GROUP"
  }
}

#CREATE PROD ELEVATE ANALYTICS SERVER
resource "aws_instance" "PROD-ELEVATE-ANALYTICS" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.PROD-ELEVATE-ANALYTICS-SG.id]
  tags = {
    Name = "PROD ELEVATE ANALYTICS"
  }
}

#CREATING PROD ELEVATE BIGBLUE BUTTON SG
resource "aws_security_group" "PROD-ELEVATE-BIGBLUE-BUTTON-SG" {
  name        = "PROD_ELEVATE_BIGBLUE_BUTTON_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 16384
    to_port          = 32768
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PROD ELEVATE BIGBLUE BUTTON SECURITY GROUP"
  }
}

#CREATE PROD ELEVATE BIGBLUE BUTTON SERVER
resource "aws_instance" "PROD-ELEVATE-BIGBLUE-BUTTON" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.PROD-ELEVATE-BIGBLUE-BUTTON-SG.id]
  tags = {
    Name = "PROD ELEVATE BIGBLUE BUTTON"
  }
}

#CREATING PROD ELEVATE DB 1 SG
resource "aws_security_group" "PROD-ELEVATE-DB-1-SG" {
  name        = "PROD_ELEVATE_DB_1_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 27017
    to_port          = 27017
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = " PROD ELEVATE DB 1 SECURITY GROUP"
  }
}

#CREATE PROD ELEVATE DB 1 SERVER

resource "aws_instance" "PROD-ELEVATE-DB-1" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.PROD-ELEVATE-DB-1-SG.id]
  tags = {
    Name = "PROD ELEVATE DB 1"
  }
}

#CREATING PROD ELEVATE KAFKA 1 SG
resource "aws_security_group" "PROD-ELEVATE-KAFKA-1-SG" {
  name        = "PROD_ELEVATE_KAFKA_1_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 9092
    to_port          = 9092
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = " PROD ELEVATE KAFKA 1 SECURITY GROUP"
  }
}

#CREATE PROD ELEVATE KAFKA 1 SERVER

resource "aws_instance" "PROD-ELEVATE-KAFKA-1" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.PROD-ELEVATE-KAFKA-1-SG.id]
  tags = {
    Name = "PROD ELEVATE KAFKA 1"
  }
}

#CREATING PROD ELEVATE REDIS 1 SG
resource "aws_security_group" "PROD-ELEVATE-REDIS-1-SG" {
  name        = "PROD_ELEVATE_REDIS_1_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 6379
    to_port          = 6379
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = " PROD ELEVATE REDIS 1 SECURITY GROUP"
  }
}

#CREATE PROD ELEVATE REDIS 1 SERVER

resource "aws_instance" "PROD-ELEVATE-REDIS-1" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.PROD-ELEVATE-REDIS-1-SG.id]
  tags = {
    Name = "PROD ELEVATE REDIS 1"
  }
}

#CREATING PROD ELEVATE SERVICES 1 SG
resource "aws_security_group" "PROD-ELEVATE-SERVICES-1-SG" {
  name        = "PROD_ELEVATE_SERVICES_1_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 3001
    to_port          = 3001
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  ingress {
    description      = "TLS from VPC"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = " PROD ELEVATE SERVICES 1 SECURITY GROUP"
  }
}

#CREATE PROD ELEVATE SERVICES 1 SERVER

resource "aws_instance" "PROD-ELEVATE-SERVICES-1" {
  ami           = "ami-03a5def6b0190cef7" # us-west-2
  instance_type = "t2.micro"
  key_name = "OHIO"
  subnet_id = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.PROD-ELEVATE-SERVICES-1-SG.id]
  tags = {
    Name = "PROD ELEVATE SERVICES 1"
  }
}
