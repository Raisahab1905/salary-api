output "scylla_private_ips" {
  description = "Private IP addresses of ScyllaDB nodes"
  value       = aws_instance.scylla_node[*].private_ip
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.salary_api.repository_url
}