# 1. RDS(PostgreSQL) 전용 보안 그룹
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-rds-sg"
  description = "Security group for PostgreSQL RDS allowing traffic from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  # 🔒 실전 방화벽 규칙 체인 결합
  # 오직 'EKS 공유 노드 그룹 명찰'을 단 애플리케이션들만 PostgreSQL 기본 포트(5432)로 들어올 수 있게 제한합니다.
  ingress {
    description     = "Allow DB access only from EKS managed nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id] # 🌟 EKS 노드 보안그룹 ID 자동 연동!
  }

  # Bastion Host에서도 DB 스키마를 마이그레이션하거나 디버깅할 수 있도록 문을 열어줍니다.
  ingress {
    description     = "Allow DB access from Bastion Host for temporary debugging"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # 🌟 Bastion 보안그룹 ID 자동 연동!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-rds-sg"
  }
}

# 2. 🔑 [보안 우대사항] 마스터 패스워드 자동 생성 및 관리 (AWS Secrets Manager)
# 코드에 비밀번호를 노출하지 않고 AWS가 무작위 비밀번호를 자동으로 만들게 합니다.
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${var.environment}-rds-master-credentials"
  recovery_window_in_days = 0 # 삭제 시 즉시 삭제되도록 설정
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "postgres_admin"
    password = random_password.db_password.result
    # 🌟 ESO가 DB_HOST로 매핑할 수 있도록 RDS 접속 정보 추가
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = "ordermsa"
  })
}

# 3. RDS 인스턴스가 들어갈 서브넷 그룹 지정 (VPC의 Private 서브넷 사용)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.environment}-rds-subnet-group"
  }
}

# 4. 🐘 PostgreSQL RDS 인스턴스 생성
resource "aws_db_instance" "postgres" {
  identifier        = "${var.environment}-postgres-db"
  allocated_storage = 20 # 기본 20GB 할당
  engine            = "postgres"
  engine_version    = "16.1" # 검증된 최신 안정 버전인 PostgreSQL 16 대역 채택
  instance_class    = "db.t4g.micro" # 💸 AWS 자체 Graviton 가성비 칩 적용! 지갑 보호용 최적 스펙

  # 🔐 Secrets Manager에서 생성된 크레덴셜 동적 주입
  username = "postgres_admin"
  password = random_password.db_password.result

  # 🌟 애플리케이션이 접속하는 초기 DB 자동 생성 (앱 jdbc url: .../ordermsa)
  db_name = "ordermsa"

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true # 인프라 삭제 테스트 시 빠른 삭제를 위해 최종 스냅샷 생략

  # 🌐 외부 노출 완벽 차단
  publicly_accessible = false

  tags = {
    Name        = "${var.environment}-postgres-db"
    Environment = var.environment
    Terraform   = "true"
  }
}