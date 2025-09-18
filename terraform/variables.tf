variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "scylla_ami" {
  description = "AMI ID for ScyllaDB nodes"
  default     = "ami-03aa99ddf5498ceb9"  # Replace with actual ScyllaDB AMI
}

variable "scylla_instance_type" {
  description = "Instance type for ScyllaDB nodes"
  default     = "i3.xlarge"  # Recommended for ScyllaDB
}

variable "scylla_keyspace" {
  description = "ScyllaDB keyspace name"
  default     = "salary_api"
}

variable "redis_node_type" {
  description = "Elasticache Redis node type"
  default     = "cache.t3.micro"
}