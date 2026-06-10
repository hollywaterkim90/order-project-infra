# 1. 카프카(MSK) 전용 보안 그룹
resource "aws_security_group" "kafka_sg" {
  name        = "${var.environment}-kafka-sg"
  description = "Security group for AWS MSK Cluster"
  vpc_id      = module.vpc.vpc_id

  # 🔒 실전 보안 규칙 체인 결합
  # 오직 'EKS 공유 노드 그룹 명찰'을 단 애플리케이션들만 카프카 브로커 포트(9092, 9094)로 들어올 수 있게 제한합니다.
  ingress {
    description     = "Allow traffic from EKS nodes"
    from_port       = 9092 # Plaintext 통신 포트
    to_port         = 9094 # TLS 암호화 통신 포트
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id] # 🌟 EKS 노드 보안그룹 ID 자동 연동!
  }

  # Bastion Host에서도 카프카 토픽 상태를 관리하거나 디버깅할 수 있도록 문을 열어줍니다.
  ingress {
    description     = "Allow traffic from Bastion Host for debugging"
    from_port       = 9092
    to_port         = 9094
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
    Name = "${var.environment}-kafka-sg"
  }
}

# 2. AWS MSK (Managed Streaming for Apache Kafka) 클러스터 정의
resource "aws_msk_cluster" "kafka" {
  cluster_name           = "${var.environment}-kafka-cluster"
  kafka_version          = "3.6.0" # 대기업 실무에서도 가장 선호하는 검증된 안정 버전
  number_of_broker_nodes = 3       # 서울 리전의 3개 가용구역(AZ: a, c, d)에 각각 1개씩 대형 브로커 배치 (고가용성 확보)

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    
    # 🌐 외부 노출 100% 차단: 1단계에서 만든 VPC의 Private 서브넷에만 물리적으로 묶어버립니다.
    client_subnets  = module.vpc.private_subnets
    security_groups = [aws_security_group.kafka_sg.id]
    
    storage_info {
      ebs_storage_info {
        volume_size = 20 # 브로커당 기본 20GB 디스크 할당
      }
    }
  }

  # 클러스터 내의 데이터 전송 암호화 설정 (실무 표준)
  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT" # 테스트 편의상 TLS와 일반 통신 둘 다 열어둡니다.
      in_cluster    = true
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# 3. 🌟 애플리케이션(ordering/product) Deployment의 KAFKA_SERVERS에 넣을 브로커 주소 출력
#    client_broker = TLS_PLAINTEXT 이므로 PLAINTEXT(9092) 주소를 사용합니다.
output "msk_bootstrap_brokers" {
  description = "ordering/product depl_svc.yml의 KAFKA_SERVERS 값으로 붙여넣을 MSK PLAINTEXT bootstrap brokers"
  value       = aws_msk_cluster.kafka.bootstrap_brokers
}