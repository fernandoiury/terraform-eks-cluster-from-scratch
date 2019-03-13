variable eks_region {
  default = "us-east-1"
}

variable cluster_name {
  default = "test-fernando" # create_cluster.sh / do not remove this comment
}

variable cluster_version {
  default = "1.11"
}

variable environment_name {
  default = "test"
}

variable vpc_cidr {
  default     = "10.0.0.0/16"
}

variable eks_public_cidrs {
  type        = "list"
  description = "List of subnet CIDR blocks. Each subnet will be sent to a different Availability Zone in the aws_region."
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable eks_private_cidrs {
  type        = "list"
  description = "List of subnet CIDR blocks. Each subnet will be sent to a different Availability Zone in the aws_region."
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable eks_azs {
  type        = "list"
  description = "List of subnet CIDR blocks. Each subnet will be sent to a different Availability Zone in the aws_region."
  default     = ["us-east-1a", "us-east-1b"]
}

variable my_external_ip {
  type    = "list"
  default = ["10.10.10.10/32"] # change this to your external IP
}

variable ssh_key_name {
  default = "my-ssh-key" # change this to your ssh-key
}

variable worker_instance_type {
  default = "t3.medium"
}

variable volume_size {
  default = "100"
}

variable asg_desired_capacity {
  default = 2
}

variable asg_max_size {
  default = 2
}
