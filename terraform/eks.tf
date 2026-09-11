module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.project_name}-cluster"
  kubernetes_version = var.kubernetes_version

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    coredns = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    main = {
      name = "${var.project_name}-nodes"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 4
      desired_size = 1
    }
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}