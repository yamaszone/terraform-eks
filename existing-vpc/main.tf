terraform {
  required_version = "= 0.11.7"
}

provider "aws" {
  version = ">= 1.24.0"
  region  = "${var.region}"
}

provider "random" {
  version = "= 1.3.1"
}

locals {
  cluster_name = "eks-${random_string.suffix.result}"

  worker_groups = "${list(
                    map("asg_desired_capacity", "1",
                        "asg_max_size", "1",
                        "asg_min_size", "1",
                        "instance_type", "m5.large",
                        "name", "worker_group_a",
                    ),
  )}"

  tags = "${map("Environment", "test",
                "GithubRepo", "terraform-aws-eks",
                "GithubOrg", "terraform-aws-modules",
                "Workspace", "${terraform.workspace}",
  )}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "eks" {
  source        = "terraform-aws-modules/eks/aws"
  version       = "1.2.0"
  cluster_name  = "${local.cluster_name}"
  subnets       = "${var.subnets}"
  tags          = "${local.tags}"
  vpc_id        = "${var.vpc_id}"
  worker_groups = "${local.worker_groups}"
}
