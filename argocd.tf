# argocd.tf

# 1. 테라폼이 EKS 클러스터 내부에 배포(Helm)할 수 있도록 권한을 연결하는 프로바이더 설정
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    # AWS CLI를 통해 실시간으로 EKS 접속 인증 토큰을 생성하여 보안 접속합니다.
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

# 2. 쿠버네티스 공식 패키지 매니저(Helm)를 이용해 ArgoCD를 설치합니다.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm" # ArgoCD 공식 헬름 저장소
  chart            = "argo-cd"
  version          = "7.1.3" # 2026년 기준 검증된 안정 버전
  namespace        = "argocd"
  create_namespace = true # argocd 전용 방(Namespace)이 없으면 자동으로 만들어라!

  # 🔒 실무형 보안 및 관리 설정 (Values 주입)
  set {
    name  = "server.service.type"
    value = "ClusterIP" # 외부 노출은 나중에 Ingress(ALB)로 안전하게 뚫을 예정이므로 내부용으로 선언!
  }

  set {
    name  = "server.rbacConfig.policy.default"
    value = "role:admin" # 포트폴리오 관리 편의를 위해 기본 권한을 admin으로 세팅
  }

  # ⚠️ 초핵심: 2단계에서 만든 EKS 클러스터 '기둥'이 완전히 완공된 후 이 코드가 실행되도록 순서를 강제합니다.
  depends_on = [module.eks]
}