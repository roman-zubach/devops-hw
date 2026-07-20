locals {
  app_namespace = "default"
}

resource "kubernetes_secret" "django_app" {
  metadata {
    name      = "django-app-secrets"
    namespace = local.app_namespace
  }

  type = "Opaque"

  data = {
    POSTGRES_HOST     = module.rds.endpoint
    POSTGRES_PASSWORD = var.db_password
    DJANGO_SECRET_KEY = random_password.django_secret_key.result
  }

  depends_on = [module.eks]
}
