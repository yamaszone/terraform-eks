variable "vpc_id" {
  description = "ID of the VPC to deploy the cluster to."
  type        = "string"
}

variable "cidr" {
  description = "CIDR block for internal security groups."
}

variable "cluster_name" {
  description = "Name of the cluster. For tagging."
  type        = "string"
}

variable "environment" {
  description = "Name of the environment, e.g. dev, prod, etc."
  type        = "string"
}

resource "aws_security_group" "masters" {
  name        = "${var.cluster_name}-masters"
  description = "Security group for the EKS cluster."

  vpc_id = "${var.vpc_id}"
}

resource "aws_security_group" "workers" {
  name        = "${var.cluster_name}-workers"
  description = "Security group for the EKS workers."

  vpc_id = "${var.vpc_id}"
}

### SG Rules HTTPS worker to master
resource "aws_security_group_rule" "in_worker_to_master_https" {
  description = "HTTPS communation from the worker nodes."

  type = "ingress"

  from_port = 443
  to_port   = 443

  protocol = "tcp"

  security_group_id        = "${aws_security_group.masters.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
}

resource "aws_security_group_rule" "out_worker_to_all" {
  description = "Worker nodes can talk to anything."

  type = "egress"

  from_port = 0
  to_port   = 0

  protocol = "-1"

  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.workers.id}"
}

### SG Rules All TCP master to worker
resource "aws_security_group_rule" "in_master_to_worker_all_tcp" {
  description = "TCP communication from master nodes."

  type      = "ingress"
  from_port = 1025
  to_port   = 65535

  protocol = "tcp"

  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.masters.id}"
}

resource "aws_security_group_rule" "out_master_to_worker_all_tcp" {
  description = "TCP communication to worker nodes."

  type      = "egress"
  from_port = 1025
  to_port   = 65535

  protocol = "tcp"

  security_group_id        = "${aws_security_group.masters.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
}

### SG Rules All worker to worker
resource "aws_security_group_rule" "in_worker_to_worker_all" {
  description = "All communication in from other worker nodes."

  type      = "ingress"
  from_port = 0
  to_port   = 0

  protocol = "-1"

  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
}

#### ssh all to worker
#resource "aws_security_group_rule" "in_all_to_worker_ssh" {
#  description = "ssh in from anywhere."
#
#  type      = "ingress"
#  from_port = 22
#  to_port   = 22
#
#  protocol = "tcp"
#
#  cidr_blocks = ["0.0.0.0/0"]
#
#  security_group_id = "${aws_security_group.workers.id}"
#}
resource "aws_security_group" "external_ssh" {
  name        = "${format("%s-%s-external-ssh", var.cluster_name, var.environment)}"
  description = "Allows ssh from the world"
  vpc_id      = "${var.vpc_id}"

  ingress {
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

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s external ssh", var.cluster_name)}"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "internal_ssh" {
  name        = "${format("%s-%s-internal-ssh", var.cluster_name, var.environment)}"
  description = "Allows ssh from bastion"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.external_ssh.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr}"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s internal ssh", var.cluster_name)}"
    Environment = "${var.environment}"
  }
}

// External SSH allows ssh connections on port 22 from the world.
output "external_ssh" {
  value = "${aws_security_group.external_ssh.id}"
}

// Internal SSH allows ssh connections from the external ssh security group.
output "internal_ssh" {
  value = "${aws_security_group.internal_ssh.id}"
}

output "sg_id_masters" {
  description = "ID of the security group for the EKS cluster."
  value       = "${aws_security_group.masters.id}"
}

output "sg_id_workers" {
  description = "ID of the security group for the works ASG."
  value       = "${aws_security_group.workers.id}"
}

