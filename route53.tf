# 퍼블릭 호스팅 영역
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

# HTTPS 인증서는 cert-manager(Let's Encrypt, https.yml)가 ingress-nginx에서 발급/종단하므로
# ACM 인증서는 사용하지 않는다 (이 구성에서 NLB는 L4 패스스루).

# 외부 트래픽을 EKS 관문(NLB)으로 꽂아주는 Route53 A 레코드
resource "aws_route53_record" "eks_ingress" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "api.${var.domain_name}" # api.hollywaterkim.shop
  type    = "A"

  alias {
    name                   = data.aws_lb.eks_nlb.dns_name
    zone_id                = data.aws_lb.eks_nlb.zone_id
    evaluate_target_health = true
  }
}

# EKS 내부의 ingress-nginx가 생성한 AWS NLB 자원을 추적하는 데이터 소스
data "aws_lb" "eks_nlb" {
  tags = {
    "kubernetes.io/service-name" = "ingress-nginx/ingress-nginx-controller"
  }
}