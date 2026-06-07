module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = "${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  # 고가용성을 위해 3개 AZ 사용
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # 실전형 NAT 게이트웨이 설정 (PROD 환경은 AZ별 1개 권장, 비용 절감 필요시 single_nat_gateway = true)
  enable_nat_gateway     = true
  single_nat_gateway    = true
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS가 서브넷을 올바르게 인식하고 LoadBalancer를 생성할 수 있도록 서브넷 태깅 필수
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-eks" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.environment}-eks" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}