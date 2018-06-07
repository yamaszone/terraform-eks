variable "name" {
  description = "Name of this stack"
}

variable "cluster_name" {
  description = "Name of this stack"
}

variable "environment" {
  description = "Name of your environment, e.g. dev, stg, prod, etc."
}

variable "key_name" {
  description = "SSH keypair"
}

variable "region" {
  description = "AWS region. Default us-west-2"
}

variable "cidr" {
  description = "VPC CIDR block"
  default     = "10.30.0.0/16"
}

variable "internal_subnets" {
  description = "List of private subnets"
  type        = "list"
}

variable "external_subnets" {
  description = "List of public subnets"
  type        = "list"
}

variable "availability_zones" {
  description = "AZ list"
  type = "list"
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion"
  default = "t2.micro"
}

variable "bastion_volume_size" {
  description = "Volume size in GB"
}

variable "policy_arn_eks_cluster" {
  description = "ARN of the default policy: AmazonEKSClusterPolicy."
  type        = "string"
}

variable "policy_arn_eks_service" {
  description = "ARN of the default policy: AmazonEKSServicePolicy."
  type        = "string"
}

variable "policy_arn_eks_worker" {
  description = "ARN of the default policy: AmazonEKSWorkerNodePolicy"
  type        = "string"
}

variable "policy_arn_eks_cni" {
  description = "ARN of the default policy: AmazonEKS_CNI_Policy"
  type        = "string"
}

variable "policy_arn_ecr_read" {
  description = "ARN of the default policy: AmazonEC2ContainerRegistryReadOnly"
  type        = "string"
}

provider "aws" {
  version = "~> 1.22"
  region  = "${var.region}"
}

module "vpc" {
  source             = "./vpc"
  name               = "${var.name}"
  cidr               = "${var.cidr}"
  internal_subnets   = "${var.internal_subnets}"
  external_subnets   = "${var.external_subnets}"
  availability_zones = "${var.availability_zones}"
  environment        = "${var.environment}"
}

module "security_groups" {
  source      = "./security-groups"
  cluster_name= "${var.cluster_name}"
  vpc_id      = "${module.vpc.id}"
  environment = "${var.environment}"
  cidr        = "${var.cidr}"
}

module "bastion" {
  source          = "./bastion"
  region          = "${var.region}"
  instance_type   = "${var.bastion_instance_type}"
  volume_size     = "${var.bastion_volume_size}"
  security_groups = "${module.security_groups.external_ssh},${module.security_groups.internal_ssh}"
  vpc_id          = "${module.vpc.id}"
  subnet_id       = "${element(module.vpc.external_subnets, 0)}"
  key_name        = "${var.key_name}"
  environment     = "${var.environment}"
}

module "iam" {
  source = "./iam"

  policy_arn_eks_cni     = "${var.policy_arn_eks_cni}"
  policy_arn_eks_service = "${var.policy_arn_eks_service}"
  policy_arn_ecr_read    = "${var.policy_arn_ecr_read}"
  policy_arn_eks_cluster = "${var.policy_arn_eks_cluster}"
  policy_arn_eks_worker  = "${var.policy_arn_eks_worker}"
}

module "eks" {
  source                 = "./eks"

  cluster_name           = "${var.cluster_name}"
  role_arn               = "${module.iam.role_arn_eks_basic_masters}"
  cluster_subnets        = "${module.vpc.external_subnets}"
  sg_id_cluster          = "${module.security_groups.sg_id_masters}"
}

module "worker" {
  source = "./worker"

  # Use module output to wait for masters to create.
  cluster_name                  = "${module.eks.cluster_id}"
  instance_profile_name_workers = "${module.iam.instance_profile_name_workers}"
  worker_subnets                = "${module.vpc.external_subnets}"
  sg_id_workers                 = "${module.security_groups.sg_id_workers}"
}

// The region in which the infra lives.
output "region" {
  value = "${var.region}"
}

// The bastion host IP.
output "bastion_ip" {
  value = "${module.bastion.external_ip}"
}


// Comma separated list of internal subnet IDs.
output "internal_subnets" {
  value = "${module.vpc.internal_subnets}"
}

// Comma separated list of external subnet IDs.
output "external_subnets" {
  value = "${module.vpc.external_subnets}"
}

// The environment of the stack, e.g "prod".
output "environment" {
  value = "${var.environment}"
}

// The VPC availability zones.
output "availability_zones" {
  value = "${module.vpc.availability_zones}"
}

// The VPC security group ID.
output "vpc_security_group" {
  value = "${module.vpc.security_group}"
}

// The VPC ID.
output "vpc_id" {
  value = "${module.vpc.id}"
}

// Comma separated list of internal route table IDs.
output "internal_route_tables" {
  value = "${module.vpc.internal_rtb_id}"
}

output "external_route_tables" {
  value = "${module.vpc.external_rtb_id}"
}

output "endpoint" {
  description = "Endpoint of the cluster."
  value       = "${module.eks.endpoint}"
}

output "cluster_id" {
  description = "The name of the cluster."
  value       = "${module.eks.cluster_id}"
}

### kubecfg

locals {
  kubeconfig-aws-1-10 = <<KUBECONFIG

apiVersion: v1
clusters:
- cluster:
    server: ${module.eks.endpoint}
    certificate-authority-data: ${module.eks.kubeconfig-certificate-authority-data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - "token"
        - "-i"
        - "${module.eks.cluster_id}"

KUBECONFIG
}

locals {
  worker_iam_role_arn  = <<ROLEARN

apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${module.iam.role_arn_eks_basic_workers}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes

ROLEARN
}

output "kubeconfig-aws-1-10" {
  description = "Kubeconfig to connect to the cluster."
  value       = "${local.kubeconfig-aws-1-10}"
}

output "role_arn_eks_basic_workers" {
  description = "ARN of the eks-basic-workers role."
  value       = "${local.worker_iam_role_arn}"
}
