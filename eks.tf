module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = "${var.environment}-eks"
  cluster_version = "1.31"

  # 네트워크 연결
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # 노드는 무조건 Private 서브넷에 배치

  # 실전 보안: API 서버 엔드포인트 보안 강화
  # 보안 요구사항에 따라 완전히 내부(false)로 돌리거나, 외부 접근 시 퍼블릭 CIDR 블록 제한을 걸어야 합니다.
  cluster_endpoint_public_access  = true 
  # cluster_endpoint_public_access_cidrs = ["210.xx.xx.xx/32"] # 필요한 경우 회사 IP만 화이트리스트

  # 내부 통신 표준을 위한 필수 애드온 구성
  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true } # IP 고갈 방지 및 노드 준비 가속화
    eks-pod-identity-agent = { before_compute = true } # 서비스 계정 권한 관리를 위한 최신 표준
  }

  # 클러스터 생성자에게 관리자(ClusterAdmin) 권한 자동 부여
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  # 실전형 관리형 노드 그룹 (Managed Node Group) 설정
  eks_managed_node_groups = {
    # 일반 애플리리케이션 워크로드용 노드 그룹
    general = {
      name         = "node-group-general"
      ami_type     = "AL2023_x86_64_STANDARD" # 최신 Amazon Linux 2023 적용
      instance_types = ["t3.medium"]          # 운영 환경에서는 대개 m5.large 이상 권장

      min_size     = 2
      max_size     = 5
      desired_size = 2

      # 서비스 중단 없는 롤링 업데이트를 위한 설정
      update_config = {
        max_unavailable_percentage = 33
      }

      labels = {
        role = "general"
      }

      tags = {
        Environment = var.environment
      }
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}