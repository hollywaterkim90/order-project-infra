variable "aws_region" {
  description = "인프라가 배포될 AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "배포 환경 구분 (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "서비스에 사용할 루트 도메인"
  type        = string
  default     = "hollywaterkim.shop" 
}