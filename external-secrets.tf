# external-secrets.tf
# AWS Secrets Manager의 RDS 크레덴셜을 EKS Secret(my-app-secrets)으로 동기화하기 위한
# External Secrets Operator(ESO) 설치 + EKS Pod Identity 기반 IAM 권한 연결.

# =====================================================================
# 1. ESO 설치 (Helm)
# =====================================================================
# 차트가 namespace 'external-secrets'에 ServiceAccount 'external-secrets'를 생성합니다.
# 아래 Pod Identity Association이 바로 이 SA에 IAM 권한을 붙입니다.
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.10.7" # ⚠️ external-secrets.io/v1 API를 제공하는 0.10+ 대역. `helm search repo`로 확인 후 고정.
  namespace        = "external-secrets"
  create_namespace = true

  # CRD(ExternalSecret/ClusterSecretStore 등) 함께 설치
  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [module.eks]
}

# =====================================================================
# 2. ESO 컨트롤러가 사용할 IAM Role (EKS Pod Identity로 위임)
# =====================================================================
data "aws_iam_policy_document" "eso_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"] # 🌟 Pod Identity 전용 서비스 프린시펄
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.environment}-eso-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.eso_assume.json

  tags = {
    Name      = "${var.environment}-eso-secrets-role"
    Terraform = "true"
  }
}

# 🔒 최소 권한: RDS 마스터 크레덴셜 시크릿 하나만 읽기 허용
data "aws_iam_policy_document" "eso_read_secret" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.db_secret.arn]
  }
}

resource "aws_iam_role_policy" "eso_read_secret" {
  name   = "${var.environment}-eso-read-rds-secret"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso_read_secret.json
}

# =====================================================================
# 3. Pod Identity Association: ESO 컨트롤러 SA ↔ IAM Role 연결
# =====================================================================
resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso.arn

  depends_on = [helm_release.external_secrets]
}
