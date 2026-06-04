# 퍼블릭 호스팅 영역 정의
resource "aws_route53_zone" "primary" {
  name          = var.domain_name
  force_destroy = false # 실수로 도메인 존이 삭제되는 것을 방지

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# ALB 인그레스 등에서 즉시 가져다 쓸 수 있는 와일드카드 SSL 인증서 발급
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  # 루트 도메인과 하위 서브도메인(*.yourcompany.com) 모두 커버
  subject_alternative_names = ["*.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
  }
}

# Route53을 통한 ACM DNS 검증 레코드 자동 생성
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

# 인증서 유효성 검증 완료 단계 선언 (이 자원이 완료되어야 다른 인프라에서 인증서 사용 가능)
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}