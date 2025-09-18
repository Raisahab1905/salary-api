provider "aws" {
  region = var.region
}

# VPC (same as before)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "three-tier-vpc"
  }
}

# Subnets (same as before)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(["10.0.1.0/24", "10.0.2.0/24"], count.index)
  availability_zone       = element(["${var.region}a", "${var.region}b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(["10.0.3.0/24", "10.0.4.0/24"], count.index)
  availability_zone = element(["${var.region}a", "${var.region}b"], count.index)
  tags = {
    Name = "private-app-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(["10.0.5.0/24", "10.0.6.0/24"], count.index)
  availability_zone = element(["${var.region}a", "${var.region}b"], count.index)
  tags = {
    Name = "private-db-subnet-${count.index + 1}"
  }
}

# Internet Gateway, NAT Gateway, Route Tables (same as before)

# Security Groups - Modified for ScyllaDB and Redis
resource "aws_security_group" "web" {
  # ... (same as before)
}

resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "Allow traffic from web layer to app layer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

resource "aws_security_group" "scylla" {
  name        = "scylla-sg"
  description = "Allow traffic from app layer to ScyllaDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 9042  # ScyllaDB default port
    to_port         = 9042
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "scylla-sg"
  }
}

resource "aws_security_group" "redis" {
  name        = "redis-sg"
  description = "Allow traffic from app layer to Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379  # Redis default port
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "redis-sg"
  }
}

# ALB and Target Group (same as before)

# ScyllaDB Cluster (using EC2 instances as ScyllaDB Cloud isn't directly available in Terraform)
resource "aws_instance" "scylla_node" {
  count         = 3  # 3-node cluster for high availability
  ami           = var.scylla_ami
  instance_type = var.scylla_instance_type
  subnet_id     = aws_subnet.private_db[count.index % length(aws_subnet.private_db)].id
  vpc_security_group_ids = [aws_security_group.scylla.id]
  
  # IAM instance profile for ScyllaDB (if needed)
  iam_instance_profile = aws_iam_instance_profile.scylla_instance_profile.name
  
  tags = {
    Name = "scylla-node-${count.index + 1}"
  }

  user_data = <<-EOF
              #!/bin/bash
              # ScyllaDB installation script
              curl -L http://downloads.scylladb.com/deb/ubuntu/scylla-5.1.list -o /etc/apt/sources.list.d/scylla.list
              apt-get update
              apt-get install -y scylla
              scylla_setup --disks /dev/nvme1n1 --nic eth0 --setup-nic --no-verify-package
              systemctl start scylla-server
              EOF
}

# Elasticache Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "salary-api-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  port                 = 6379
  security_group_ids   = [aws_security_group.redis.id]
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id
}

# ECS Configuration (updated environment variables)
resource "aws_ecs_task_definition" "salary_api" {
  family                   = "salary-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "salary-api"
    image     = "${aws_ecr_repository.salary_api.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    environment = [
      {
        name  = "SCYLLA_HOSTS"
        value = join(",", aws_instance.scylla_node[*].private_ip)
      },
      {
        name  = "SCYLLA_KEYSPACE"
        value = var.scylla_keyspace
      },
      {
        name  = "REDIS_HOST"
        value = aws_elasticache_cluster.redis.cache_nodes[0].address
      },
      {
        name  = "REDIS_PORT"
        value = tostring(aws_elasticache_cluster.redis.port)
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/salary-api"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# IAM Role for ScyllaDB instances
resource "aws_iam_instance_profile" "scylla_instance_profile" {
  name = "scylla-instance-profile"
  role = aws_iam_role.scylla_instance_role.name
}

resource "aws_iam_role" "scylla_instance_role" {
  name = "scylla-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
