# ingress-cert.tf
# Ingress(ingress.yml)와 TLS 인증서(https.yml)가 동작하기 위한 전제 컴포넌트 설치.
#   - ingress-nginx : ingress.yml의 `ingress.class: nginx` 를 처리하는 컨트롤러 (+ AWS NLB)
#   - cert-manager  : https.yml의 ClusterIssuer/Certificate(Let's Encrypt http01) 발급 담당

# =====================================================================
# 1. NGINX Ingress Controller (helm)
# =====================================================================
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3" # ⚠️ controller 1.11.x 대역. `helm search repo ingress-nginx`로 확인 후 고정.
  namespace        = "ingress-nginx"
  create_namespace = true

  # AWS NLB로 외부 노출 (in-tree cloud provider 기준)
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  depends_on = [module.eks]
}

# =====================================================================
# 2. cert-manager (helm)
# =====================================================================
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.16.2" # ⚠️ `helm search repo jetstack/cert-manager`로 확인 후 고정.
  namespace        = "cert-manager"
  create_namespace = true

  # CRD(Certificate/ClusterIssuer 등) 함께 설치
  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [module.eks]
}
