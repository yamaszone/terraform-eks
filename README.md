# Terraform EKS Cluster
PoC for EKS cluster deployment

__NOTE__: deploying an EKS cluster will incur cost for AWS resources.

## Prerequisites
- Download Heptio Authenticator
  - `curl -o heptio-authenticator-aws https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/linux/amd64/heptio-authenticator-aws` # Linux
  - `curl -o heptio-authenticator-aws https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/heptio-authenticator-aws` # macOS
- Install Heptio Authenticator
  - `chmod +x heptio-authenticator-aws && sudo mv heptio-authenticator-aws /opt/bin/` # CoreOS
  - `chmod +x heptio-authenticator-aws && sudo mv heptio-authenticator-aws /usr/local/bin/` # macOS/Linux
- Install `kubectl`
  - `curl -o https://storage.googleapis.com/kubernetes-release/release/v1.10.3/bin/linux/amd64/kubectl`
  - `chmod +x kubectl && sudo mv kubectl /opt/bin/kubectl` # CoreOS
  - `chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl` # macOS/Linux

## Quickstart
#### Deploy
- Checkout this repo
- `./eks cluster up`
- `kubectl apply -f nginx.yaml` # Deploy an example Nginx pod
- `kubectl get pods` # Check if the Nginx pod is running
- `kubectl get svc -o wide` # Locate the service URL for Nginx
- Copy the Nginx URL from previous step and launch the Nginx welcome page via port 8000
  - URL may look like `http://a2ec4e6b66a2411e883240aa8289a10c-778396272.us-west-2.elb.amazonaws.com:8000/`
#### Destroy
- `kubectl delete -f nginx.yaml` # Delete Nginx pod if deployed based on the sample
- `terraform destroy`

## Credits
- [Segmentio Stack](https://github.com/segmentio/stack) for VPC related modules
- [WillJCJ](https://github.com/WillJCJ/eks-terraform-demo) for EKS related modules

