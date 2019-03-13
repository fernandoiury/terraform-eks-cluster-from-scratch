data "aws_ami" "latest-centos" {
  owners      = ["679593333241"]
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "bastion" {
  count         = 1
  ami           = "${data.aws_ami.latest-centos.id}"
  instance_type = "t2.micro"
  key_name      = "${var.ssh_key_name}"
  subnet_id     = "${element(module.eks-vpc.public_subnets, count.index)}"

  root_block_device = {
    volume_type           = "gp2"
    volume_size           = "8"
    delete_on_termination = true
  }

  tags = {
    Name        = "${format("bastion-%s%02d", var.cluster_name, count.index + 1)}"
    Environment = "${var.environment_name}"
    Terraform   = "true"
    Stack       = "${var.cluster_name}"
  }

  vpc_security_group_ids = ["${aws_security_group.bastion-sg.id}"]

  associate_public_ip_address = true
}

resource "aws_security_group" "bastion-sg" {
  name   = "bastion-security-group"
  vpc_id = "${module.eks-vpc.vpc_id}"

  tags = {
    Name        = "${var.cluster_name}-bastion-sg"
    Environment = "${var.environment_name}"
    Terraform   = "true"
    Stack       = "${var.cluster_name}"
  }

  ingress {
    description = "Allow connection on port 22 between members of this group"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = "${var.my_external_ip}"
    self        = true
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output bastion_public_ip {
  value = "${aws_instance.bastion.public_ip}"
}
