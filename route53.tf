resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "hollywaterkim.shop"
  type    = "A"

  alias {
    name                   = module.vpc.nlb_dns_name # ⚡ "VPC 모듈이 만든 NLB 주소
    zone_id                = module.vpc.nlb_zone_id
    evaluate_target_health = true
  }
}