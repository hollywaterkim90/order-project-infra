# 1. Member 서비스용 이미지 창고
resource "aws_ecr_repository" "member_ecr" {
  name                 = "${var.environment}-member-service"
  image_tag_mutability = "MUTABLE" # 새로운 빌드가 나오면 동일한 태그(예: latest)로 덮어쓰기 허용

  # 🔐 이미지 취약점 자동 스캔 기능 활성화 (실무 필수 보안 우대사항)
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.environment}-member-ecr"
    Terraform   = "true"
  }
}

# 2. Ordering(주문) 서비스용 이미지 창고
resource "aws_ecr_repository" "ordering_ecr" {
  name                 = "${var.environment}-ordering-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.environment}-ordering-ecr"
    Terraform   = "true"
  }
}

# 3. Product(상품) 서비스용 이미지 창고
resource "aws_ecr_repository" "product_ecr" {
  name                 = "${var.environment}-product-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.environment}-product-ecr"
    Terraform   = "true"
  }
}

# =====================================================================
# 🧹 [비용 최적화] 오래된 이미지 자동 삭제 정책 (Lifecycle Policy)
# =====================================================================
# 각 레포지토리마다 최신 이미지 5개만 남기고 옛날 빌드는 자동으로 폐기합니다.

resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  for_each = toset([
    aws_ecr_repository.member_ecr.name,
    aws_ecr_repository.ordering_ecr.name,
    aws_ecr_repository.product_ecr.name
  ])

  repository = each.value

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 5 images to optimize AWS storage cost",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

# 4. API Gateway 서비스용 이미지 창고
resource "aws_ecr_repository" "apigateway_ecr" {
  name                 = "${var.environment}-apigateway"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.environment}-apigateway-ecr"
    Terraform   = "true"
  }
}

# 기존 Lifecycle Policy의 for_each 대상을 4개로 확장합니다.
resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  for_each = toset([
    aws_ecr_repository.member_ecr.name,
    aws_ecr_repository.ordering_ecr.name,
    aws_ecr_repository.product_ecr.name,
    aws_ecr_repository.apigateway_ecr.name # 🌟 게이트웨이 추가!
  ])

  repository = each.value
  policy     = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 5 images to optimize AWS storage cost",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

