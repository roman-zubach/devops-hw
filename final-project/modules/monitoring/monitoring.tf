resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

# StorageClass на базі EBS CSI Driver — динамічне сховище для PVC
# Prometheus та Grafana. WaitForFirstConsumer прив'язує том до AZ поду.
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = var.storage_class_name
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
}

# kube-prometheus-stack: Prometheus + Grafana + Alertmanager +
# node-exporter + kube-state-metrics одним чартом.
resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version != "" ? var.chart_version : null

  timeout = 900

  values = [templatefile("${path.module}/values.yaml", {
    storage_class     = kubernetes_storage_class.gp3.metadata[0].name
    grafana_password  = var.grafana_admin_password
    grafana_size      = var.grafana_storage_size
    prometheus_size   = var.prometheus_storage_size
    prometheus_retain = var.prometheus_retention
  })]

  depends_on = [kubernetes_storage_class.gp3]
}
