output "K8S_CLUSTER_PUBLIC_IPS" {
  value = module.aws-resource-creation.K8S_CLUSTER_PUBLIC_IPS
}
output "K8S_CLUSTER_PRIVATE_IPS" {
  value = module.aws-resource-creation.K8S_CLUSTER_PRIVATE_IPS
}
output "NGINX_PUBLIC_IP" {
  value = module.aws-resource-creation.NGINX_PUBLIC_IP
}
output "NGINX_PRIVATE_IP" {
  value = module.aws-resource-creation.NGINX_PRIVATE_IP
}
output "MOSIP_NGINX_SG_ID" {
  value = module.aws-resource-creation.MOSIP_NGINX_SG_ID
}
output "MOSIP_K8S_SG_ID" {
  value = module.aws-resource-creation.MOSIP_K8S_SG_ID
}
output "MOSIP_K8S_CLUSTER_NODES_PRIVATE_IP_LIST" {
  value = module.aws-resource-creation.MOSIP_K8S_CLUSTER_NODES_PRIVATE_IP_LIST
}
output "MOSIP_PUBLIC_DOMAIN_LIST" {
  value = module.aws-resource-creation.MOSIP_PUBLIC_DOMAIN_LIST
}

output "CONTROL_PLANE_NODE_1" {
  value = module.rke2-setup.CONTROL_PLANE_NODE_1
}
output "K8S_CLUSTER_PRIVATE_IPS_STR" {
  value = module.rke2-setup.K8S_CLUSTER_PRIVATE_IPS_STR
}
# Output the token
output "K8S_TOKEN" {
  value = module.rke2-setup.K8S_TOKEN
}

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = var.create_vpc ? module.base_infra[0].vpc_cidr_block : data.aws_vpc.existing[0].cidr_block
}

# Subnet Information
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = local.private_subnet_ids
}

# NAT Gateway Information (only when VPC is created)
output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = var.create_vpc ? module.base_infra[0].nat_gateway_ids : []
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = var.create_vpc ? module.base_infra[0].nat_gateway_public_ips : []
}

# Security Group
# Infrastructure Status
output "vpc_created" {
  description = "Whether VPC was created in this run"
  value       = var.create_vpc
}

# Subnet Details for Reference
output "subnet_details" {
  description = "Detailed subnet information for reference"
  value = var.create_vpc ? {
    public_subnets = [
      for i, subnet in module.base_infra[0].public_subnet_ids : {
        id   = subnet
        cidr = module.base_infra[0].public_subnet_cidrs[i]
        az   = var.availability_zones[i]
        type = "Public"
      }
    ]
    private_subnets = [
      for i, subnet in module.base_infra[0].private_subnet_ids : {
        id   = subnet
        cidr = module.base_infra[0].private_subnet_cidrs[i]
        az   = var.availability_zones[i]
        type = "Private"
      }
    ]
  } : null
}