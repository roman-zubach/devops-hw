resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
  }
}

data "aws_iam_policy_document" "agent_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.agent_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agent" {
  name               = "${var.cluster_name}-jenkins-agent"
  assume_role_policy = data.aws_iam_policy_document.agent_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "agent_ecr" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "agent_ecr" {
  name   = "ecr-push"
  role   = aws_iam_role.agent.id
  policy = data.aws_iam_policy_document.agent_ecr.json
}

resource "kubernetes_service_account" "agent" {
  metadata {
    name      = var.agent_service_account
    namespace = kubernetes_namespace.jenkins.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.agent.arn
    }
  }
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.chart_version

  timeout = 900

  values = [
    templatefile("${path.module}/values.yaml", {
      admin_user            = var.admin_user
      admin_password        = var.admin_password
      namespace             = var.namespace
      agent_service_account = var.agent_service_account
      job_repo_url          = var.job_repo_url
      job_repo_branch       = var.job_repo_branch
      jenkinsfile_path      = var.jenkinsfile_path
    })
  ]

  depends_on = [kubernetes_service_account.agent]
}
