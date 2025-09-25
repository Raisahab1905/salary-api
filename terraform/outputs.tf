output "app_public_ip" {
description = "Public IP of the App instance"
value = aws_instance.app.public_ip
}


output "app_public_dns" {
description = "Public DNS of the App instance"
value = aws_instance.app.public_dns
}


output "scylla_private_ip" {
description = "Scylla EC2 Private IP"
value = aws_instance.scylla.private_ip
}


output "redis_private_ip" {
description = "Redis EC2 Private IP"
value = aws_instance.redis.private_ip
}