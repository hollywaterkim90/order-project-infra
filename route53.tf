# 퍼블릭 호스팅 영역
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

# 2. AWS ACM을 통해 SSL 인증서 신청
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS" # 가비아 네임서버가 AWS로 이관되면, AWS가 자동으로 DNS 값을 심어 검증합니다.

  # 루트 도메인과 서브 도메인(api, argocd 등)을 하나의 인증서로 모두 커버하기 위해 와일드카드 추가
  subject_alternative_names = ["*.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# 3. ACM 인증서 발급을 위한 Route53 DNS 검증 레코드 자동 생성
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

# 4. 인증서 유효성 검증 완료 선언 (이 자원이 활성화되어야 NLB나 인그레스에서 HTTPS 인증서를 쓸 수 있음)
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# 5. 외부 트래픽을 EKS 관문(NLB)으로 꽂아주는 Route53 A 레코드
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