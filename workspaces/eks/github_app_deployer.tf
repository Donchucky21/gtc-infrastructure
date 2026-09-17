data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_app_deployer_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        data.aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:Donchucky21/incident-management-portal:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "github_app_deployer" {
  name               = "${local.name}-github-app-deployer"
  assume_role_policy = data.aws_iam_policy_document.github_app_deployer_trust.json

  tags = local.tags
}

data "aws_iam_policy_document" "github_app_deployer_permissions" {
  statement {
    sid       = "ECRLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushApplicationImages"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      "arn:aws:ecr:${local.region}:${data.aws_caller_identity.current.account_id}:repository/incident-portal-backend",
      "arn:aws:ecr:${local.region}:${data.aws_caller_identity.current.account_id}:repository/incident-portal-frontend"
    ]
  }

  statement {
    sid     = "DescribeEKSCluster"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:${local.region}:${data.aws_caller_identity.current.account_id}:cluster/${local.name}"
    ]
  }
}

resource "aws_iam_role_policy" "github_app_deployer" {
  name   = "${local.name}-github-app-deployer"
  role   = aws_iam_role.github_app_deployer.id
  policy = data.aws_iam_policy_document.github_app_deployer_permissions.json
}