module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "order-eks-cluster"
  cluster_version = "1.30"

  # 🔒 보완 핵심: 외부 노출을 줄이기 위해 API 서버에 공개/비공개 제어 설정
  cluster_endpoint_public_access  = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # 🛠️ EKS 관리형 노드 그룹
  eks_managed_node_groups = {
    apps = {
      ami_type       = "AL2_x86_64"
      instance_types = ["t3.medium"] # MSA 앱 4개 + 카프카 구동을 위해 medium 스펙 채택!

      min_size     = 2
      max_size     = 4
      desired_size = 2 # 기본적으로 2대의 컴퓨터를 상시 가동 (Multi-AZ 분산)

      labels = {
        Role = "application"
      }
    }
  }

  tags = {
    Environment = "portfolio"
  }
}