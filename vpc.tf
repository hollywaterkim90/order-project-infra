# vpc.tf 수정 버전

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "order-project-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/cluster/order-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                  = "1" # ⚡ NLB가 외부 진입로로 사용할 Public 구역 선언!
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/order-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"         = "1" # 🌐 ALB가 내부에서 라우팅할 Private 구역 선언!
  }
}