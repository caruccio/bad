variable "aws_ami" {
  type    = "string"
  description = "AMI ID created by Packer"
}

variable "docker_image_name" {
  type = "string"
}

variable "private_key_file" {
  type    = "string"
}

variable "aws_region" {
  type    = "string"
  default = "us-east-1"
}

variable "aws_key_name" {
  type    = "string"
  default = "ssa"
}

variable "user" {
  type    = "string"
  default = "centos"
}

output "Instance Address" {
  value = "${aws_instance.ssa.public_ip}"
}

resource "aws_vpc" "ssa_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "ssa_subnet" {
  vpc_id                  = "${aws_vpc.ssa_vpc.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "ssa_gw" {
  vpc_id = "${aws_vpc.ssa_vpc.id}"
}

resource "aws_route_table" "ssa_rt" {
  vpc_id = "${aws_vpc.ssa_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ssa_gw.id}"
  }
}

resource "aws_route_table_association" "ssa_rta" {
  subnet_id      = "${aws_subnet.ssa_subnet.id}"
  route_table_id = "${aws_route_table.ssa_rt.id}"
}

resource "aws_security_group" "ssa_sg" {
  name        = "ssa_sg"
  vpc_id      = "${aws_vpc.ssa_vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "ssa" {
  instance_type = "t2.medium"

  ami = "${var.aws_ami}"

  key_name = "${var.aws_key_name}"

  vpc_security_group_ids = ["${aws_security_group.ssa_sg.id}"]
  subnet_id              = "${aws_subnet.ssa_subnet.id}"

  ebs_block_device = {
    delete_on_termination = true
    device_name = "/dev/xvdf"
    volume_size = 32
    volume_type = "gp2"
  }

  root_block_device = {
    delete_on_termination = true
  }

  provisioner "remote-exec" {
    inline = [ "sleep 0" ]
    connection {
      type        = "ssh"
      user        = "${var.user}"
      private_key = "${file("${var.private_key_file}")}"
      agent       = false
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --extra-vars 'docker_image_name=${var.docker_image_name}' --user ${var.user} --private-key ${var.private_key_file} --become -i '${aws_instance.ssa.public_ip},' ansible/playbook.yaml"
  }
}
