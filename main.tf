provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

#CREATING A SIMPLE VPC.
resource "aws_vpc" "test" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "terra_test_vpc"
  }
}

#CREATING A DEFAULT SECURITY GROUP.
resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.test.id}"

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terra_test_default_all"
  }
}

#CREATING THREE SUBNETS IN DIFFERENT AZs WITH A DIFFERENT CIDR.
variable "availability_zone" {}
variable "ip_block" {}
variable "bools" {}

resource "aws_subnet" "test_subnets" {
  count                   = length(var.availability_zone)
  vpc_id                  = "${aws_vpc.test.id}"
  cidr_block              = "${var.ip_block[count.index]}"
  map_public_ip_on_launch = "${var.bools[count.index]}"
  availability_zone       = "${var.availability_zone[count.index]}"
  tags = {
    Name = "terra_test_${var.ip_block[count.index]}"
  }
}

#CREATING AN INTERNET GATEWAY.
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.test.id}"

  tags = {
    Name = "terra_test_ig"
  }
}

#CREATING A NEW ROUTE TABLE FOR A PUBLICALLY ACCESSIBLE BASTION HOST.
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.test.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "terra_test_route"
  }
}

#ASSOCIATING MY BASTION HOST'S SUBNET WITH MY NEW ROUTE TABLE.
resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.test_subnets[2].id}"
  route_table_id = "${aws_route_table.r.id}"
}

#CREATING ALL THE NECESSARY INSTANCES.
resource "aws_instance" "test_hosts" {
  count                  = length(var.availability_zone)
  ami                    = "ami-02eac2c0129f6376b"
  instance_type          = "t2.micro"
  key_name               = "mymoog"
  subnet_id              = "${aws_subnet.test_subnets[count.index].id}"
  vpc_security_group_ids = ["${aws_default_security_group.default.id}"]
  tags = {
    Name = "terra_host${count.index + 1}"
  }
}

#CREATING A LOAD BALANCER.
resource "aws_lb" "test" {
  name               = "terra-test-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${aws_subnet.test_subnets[2].id}"]
  tags = {
    Environment = "production"
  }
}

#CREATING A TARGET GROUP FOR LOAD BALANCER.
resource "aws_lb_target_group" "test" {
  name     = "terra-test-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.test.id}"
}

#ATTACHING THE PRIVATE HOSTS TO LOAD BALANCER'S TARGET GROUP.
resource "aws_lb_target_group_attachment" "test" {
  count            = 2
  target_group_arn = "${aws_lb_target_group.test.arn}"
  target_id        = "${aws_instance.test_hosts[count.index].id}"
  port             = 80
}
