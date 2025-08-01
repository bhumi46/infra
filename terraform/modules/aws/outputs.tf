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