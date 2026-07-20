resource "random_password" "jenkins_admin" {
  length  = 20
  special = false
}

resource "random_password" "grafana_admin" {
  length  = 20
  special = false
}

resource "random_password" "django_secret_key" {
  length  = 50
  special = true
}
