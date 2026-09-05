locals {
  admin_access_entries = {
    for index, principal_arn in var.admin_principal_arns : index == 0 ? "cluster_creator" : "cluster_admin_${index}" => {
      principal_arn = principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  addons = {
    coredns = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {
      before_compute = true
    }
    vpc-cni = {
      before_compute = true
    }
  }

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = length(var.admin_principal_arns) == 0
  access_entries                           = local.admin_access_entries

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = coalesce(var.control_plane_subnet_ids, var.subnet_ids)

  eks_managed_node_groups = {
    "${var.cluster_name}-nodegroup" = {
      ami_type                 = "AL2023_x86_64_STANDARD"
      instance_types           = var.node_instance_types
      iam_role_name            = "${var.cluster_name}-ng"
      iam_role_use_name_prefix = false

      min_size     = var.min_nodes
      max_size     = var.max_nodes
      desired_size = var.desired_size
    }
  }

  tags = var.tags
}
