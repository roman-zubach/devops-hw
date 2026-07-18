resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  values = [file("${path.module}/values.yaml")]
}

resource "helm_release" "apps" {
  name      = "argocd-apps"
  namespace = kubernetes_namespace.argocd.metadata[0].name
  chart     = "${path.module}/charts"

  set {
    name  = "argocdNamespace"
    value = var.namespace
  }
  set {
    name  = "applications[0].name"
    value = var.app_name
  }
  set {
    name  = "applications[0].source.repoURL"
    value = var.repo_url
  }
  set {
    name  = "applications[0].source.targetRevision"
    value = var.repo_target_revision
  }
  set {
    name  = "applications[0].source.path"
    value = var.chart_path
  }
  set {
    name  = "applications[0].destination.namespace"
    value = var.destination_namespace
  }
  set {
    name  = "applications[0].imageRepository"
    value = var.image_repository
  }
  set {
    name  = "repositories[0].name"
    value = var.app_name
  }
  set {
    name  = "repositories[0].url"
    value = var.repo_url
  }

  depends_on = [helm_release.argocd]
}
