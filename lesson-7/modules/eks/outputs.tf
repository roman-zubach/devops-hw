output "cluster_name" {
  description = "Ім'я EKS-кластера"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint API-сервера кластера"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "CA сертифікат кластера (base64)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_arn" {
  description = "ARN кластера"
  value       = aws_eks_cluster.this.arn
}

output "cluster_security_group_id" {
  description = "ID security group кластера"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN OIDC-провайдера для IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_group_name" {
  description = "Ім'я managed node group"
  value       = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  description = "ARN IAM-ролі worker-нод"
  value       = aws_iam_role.node.arn
}
