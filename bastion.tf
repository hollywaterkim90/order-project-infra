# 1. Bastion Host 전용 보안 그룹 (Security Group)
# 외부에서는 철저히 차단하고, 특정 안전한 통로로만 접속을 허용합니다.
resource "aws_security_group" "bastion_sg" {
  name        = "${var.environment}-bastion-sg"
  description = "Security Group for Bastion Host"
  vpc_id      = module.vpc.vpc_id # 1단계에서 만든 VPC 변수 연동

  # 🔒 인바운드 규칙: 실무에서는 22번 포트를 전세계에 열지 않고 내 IP만 지정하는 것이 정석입니다.
  # 테스트 편의를 위해 일단 전면 개방(0.0.0.0/0) 상태로 두고, 차후 "내 IP/32"로 잠그는 것을 우대사항으로 어필하세요!
  ingress {
    description = "Allow SSH from anywhere (Change to My IP in production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드 규칙: Bastion 내부에서 패키지 설치(yum install 등)를 위해 인터넷 출구 전면 개방
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-bastion-sg"
    Environment = var.environment
  }
}

# 2. AWS 최신 우분투(Ubuntu) 순정 이미지 정보 동적으로 가져오기
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu 공식 패키저 ID)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 3. Bastion Host EC2 인스턴스 생성
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro" # 💸 문지기 역할만 하므로 가장 저렴한 micro 스펙 채택!

  # 🌐 초핵심: 외부에서 접근해야 하므로 반드시 'Public' 서브넷 중 첫 번째(a구역)에 배치합니다.
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true # 외부 접속용 퍼블릭 고정/유동 IP 자동 부여

  # EC2 접속에 사용할 키페어 이름 (AWS 콘솔에서 미리 만들어둔 키페어 이름을 적어주세요)
  # key_name = "your-ssh-key-name" 

  # 가동 시 쿠버네티스 관리 도구(kubectl, helm)를 자동 설치해 두는 실무형 스크립트 (User Data)
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y unzip curl
              # AWS CLI 설치
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip && ./aws/install
              # kubectl 설치
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              EOF

  tags = {
    Name        = "${var.environment}-bastion-host"
    Environment = var.environment
    Terraform   = "true"
  }
}