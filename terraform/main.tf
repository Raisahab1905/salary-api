# ------------------------
# Data Sources
# ------------------------
data "aws_availability_zones" "available" {}

# ------------------------
# VPC
# ------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

# ------------------------
# Subnets
# ------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_a
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_b
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_a
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project}-${var.environment}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_b
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project}-${var.environment}-private-b"
  }
}

# ------------------------
# Internet Gateway
# ------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

# ------------------------
# Elastic IP for NAT
# ------------------------
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

# ------------------------
# NAT Gateway
# ------------------------
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.project}-${var.environment}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ------------------------
# Route Tables
# ------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-private-rt"
  }
}

# ------------------------
# Route Table Associations
# ------------------------
resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# ------------------------
# Security Groups
# ------------------------
# ALB SG
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project}-${var.environment}-alb-sg"
  description = "Allow internet to ALB and ALB to App"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-alb-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# App EC2 SG
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project}-${var.environment}-sg"

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Allow ALB traffic
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # allow app to connect
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# Scylla SG

resource "aws_security_group" "scylla_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project}-${var.environment}-scylla-sg"
  description = "Allow Scylla traffic from app layer"

  ingress {
    from_port       = 9042
    to_port         = 9042
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]  # allow app to connect
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # allow app to connect
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-scylla-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# Redis SG

resource "aws_security_group" "redis_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project}-${var.environment}-redis-sg"
  description = "Allow Redis traffic from app layer"

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]  # allow app to connect
  }
  
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # allow app to connect
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-redis-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# Bastion SG
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project}-${var.environment}-bastion-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # <-- replace with your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-bastion-sg"
  }
}

# ------------------------
# Application Load Balancer
# ------------------------
resource "aws_lb" "app_alb" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "${var.project}-${var.environment}-alb"
    Environment = var.environment
    Project     = var.project
  }

  depends_on = [aws_subnet.public_a, aws_subnet.public_b]
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.project}-${var.environment}-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/actuator/health"  # Spring Boot actuator endpoint
    port                = "8080"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project}-${var.environment}-tg"
    Environment = var.environment
    Project     = var.project
  }
}

# Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ------------------------
# EC2 Instances
# ------------------------
resource "aws_instance" "scylla" {
  ami                    = "ami-065778886ef8ec7c8"
  instance_type          = var.scylla_instance_type
  subnet_id              = aws_subnet.private_b.id
  vpc_security_group_ids = [aws_security_group.scylla_sg.id]
  key_name               = "rai" # Use existing key

  tags = {
    Name = "${var.project}-${var.environment}-scylla"
  }

  depends_on = [aws_route_table_association.private_assoc_b]

  user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Run Scylla container
docker run -d --name scylla -p 9042:9042 scylladb/scylla:latest
EOF
}

resource "aws_instance" "redis" {
  ami                    = "ami-065778886ef8ec7c8"
  instance_type          = var.redis_instance_type
  subnet_id              = aws_subnet.private_b.id
  vpc_security_group_ids = [aws_security_group.redis_sg.id]
  key_name               = "rai"

  tags = {
    Name = "${var.project}-${var.environment}-redis"
  }

  depends_on = [aws_route_table_association.private_assoc_b]

  user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Run Redis container
docker run -d --name redis -p 6379:6379 redis:latest
EOF
}

resource "aws_instance" "app" {
  ami                    = "ami-065778886ef8ec7c8"
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = "rai"

  tags = {
    Name        = "${var.project}-${var.environment}-app"
    Environment = var.environment
    Project     = var.project
  }

  depends_on = [
    aws_route_table_association.private_assoc_a,
    aws_instance.scylla,
    aws_instance.redis
  ]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io curl git netcat

              # Install Docker Compose v2
              DOCKER_COMPOSE_VERSION="v2.10.0"
              curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              systemctl enable docker
              systemctl start docker
              usermod -aG docker ubuntu

              SCYLLA_HOST=${aws_instance.scylla.private_ip}
              REDIS_HOST=${aws_instance.redis.private_ip}

              # Wait for Scylla readiness
              until nc -z $SCYLLA_HOST 9042; do
                echo "⏳ Waiting for Scylla at $SCYLLA_HOST:9042..."
                sleep 15
              done

              # Wait for Redis readiness
              until nc -z $REDIS_HOST 6379; do
                echo "⏳ Waiting for Redis at $REDIS_HOST:6379..."
                sleep 10
              done

              # Clone repo
              cd /home/ubuntu
              git clone https://github.com/Raisahab1905/salary-api.git
              cd salary-api

              # Copy wait-for script
              cp wait-for.sh /usr/local/bin/wait-for
              chmod +x /usr/local/bin/wait-for

              # Wait for DB services
              wait-for $SCYLLA_HOST 9042 60
              wait-for $REDIS_HOST 6379 60  

              # Start Salary API container
              echo "✅ Starting Salary API..."
              docker run -d -p 8080:8080 \
                -e SCYLLA_HOST=$SCYLLA_HOST \
                -e SCYLLA_PORT=9042 \
                -e SCYLLA_KEYSPACE=employee_db \
                -e REDIS_HOST=$REDIS_HOST \
                -e REDIS_PORT=6379 \
                ${var.app_image}
              EOF
}

# ------------------------
# Register App Instance with Target Group
# ------------------------
resource "aws_lb_target_group_attachment" "app_tg_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app.id
  port             = 8080
}

# ------------------------
# Bastion Host
# ------------------------
resource "aws_instance" "bastion" {
  ami                         = "ami-065778886ef8ec7c8"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = "rai"

  tags = {
    Name = "${var.project}-${var.environment}-bastion"
  }

  user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y htop
EOF
}
