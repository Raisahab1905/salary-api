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

  tags = { Name = "${var.project}-${var.environment}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_b
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project}-${var.environment}-public-b" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_a
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = "${var.project}-${var.environment}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_b
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = { Name = "${var.project}-${var.environment}-private-b" }
}

# ------------------------
# Internet Gateway
# ------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project}-${var.environment}-igw" }
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

  tags = { Name = "${var.project}-${var.environment}-nat" }
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

  tags = { Name = "${var.project}-${var.environment}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "${var.project}-${var.environment}-private-rt" }
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
# App EC2 SG
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project}-${var.environment}-app-sg"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Public access to app
  }

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "${var.project}-${var.environment}-app-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# Scylla SG
resource "aws_security_group" "scylla_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project}-${var.environment}-scylla-sg"

  ingress {
    from_port       = 9042
    to_port         = 9042
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Only app can access
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]  # allow db to connect
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

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Only app can access
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]  # allow db to connect
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

# ------------------------
# EC2 Instances
# ------------------------
resource "aws_instance" "app" {
  ami                    = "ami-065778886ef8ec7c8"
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = "rai"

  tags = {
    Name        = "${var.project}-${var.environment}-app"
    Environment = var.environment
    Project     = var.project
  }

  depends_on = [aws_instance.scylla, aws_instance.redis]

  user_data = <<-EOF
#!/bin/bash
set -e

apt-get update -y
apt-get install -y docker.io curl netcat
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Run app
docker stop salary-api || true
docker rm salary-api || true

docker run -d \
  --name salary-api \
  -p 8080:8080 \
  -e SCYLLA_HOST=$SCYLLA_HOST \
  -e SCYLLA_PORT=9042 \
  -e SCYLLA_KEYSPACE=employee_db \
  -e REDIS_HOST=$REDIS_HOST \
  -e REDIS_PORT=6379 \
  -e SPRING_PROFILES_ACTIVE=dev \
  ${var.app_image}
EOF
}

resource "aws_instance" "scylla" {
  ami                    = "ami-065778886ef8ec7c8"
  instance_type          = var.scylla_instance_type
  subnet_id              = aws_subnet.private_b.id
  vpc_security_group_ids = [aws_security_group.scylla_sg.id]
  key_name               = "rai"

  tags = { Name = "${var.project}-${var.environment}-scylla" }

  user_data = <<-EOF
#!/bin/bash
set -e

# Update and install Docker
apt-get update -y
apt-get install -y docker.io curl
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Get private IP
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Stop any existing Scylla container
docker stop scylla || true
docker rm scylla || true

# Run Scylla with HOST networking
docker run -d \
  --name scylla \
  --network host \
  scylladb/scylla:latest \
  --listen-address 0.0.0.0 \
  --rpc-address 0.0.0.0 \
  --broadcast-address $PRIVATE_IP \
  --developer-mode 1

# Wait for Scylla to start and create keyspace
echo "Waiting for ScyllaDB to start..."
for i in {1..30}; do
  if docker exec scylla cqlsh -e "DESCRIBE KEYSPACES;" 2>/dev/null; then
    echo "✅ ScyllaDB is running!"
    
    # Create the required keyspace
    docker exec scylla cqlsh -e "CREATE KEYSPACE IF NOT EXISTS employee_db WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
    echo "✅ Keyspace 'employee_db' created successfully!"
    break
  fi
  echo "⏳ Waiting for ScyllaDB to be ready... attempt $i/30"
  sleep 10
done

echo "ScyllaDB initialization completed!"
EOF
}

resource "aws_instance" "redis" {
  ami                    = "ami-065778886ef8ec7c8"
  instance_type          = var.redis_instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.redis_sg.id]
  key_name               = "rai"

  tags = { Name = "${var.project}-${var.environment}-redis" }

  user_data = <<-EOF
#!/bin/bash
set -e

apt-get update -y
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Stop any existing Redis container
docker stop redis || true
docker rm redis || true

# Run Redis container binding to all interfaces
docker run -d \
  --name redis \
  -p 0.0.0.0:6379:6379 \
  redis:latest \
  --bind 0.0.0.0 --protected-mode no

echo "Redis setup complete!"
EOF
}
