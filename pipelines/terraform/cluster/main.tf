terraform {
  backend "s3" {}
}

provider "aws" {
  region = "eu-west-2"

  assume_role {
    role_arn = "${var.aws_account_role_arn}"
  }
}

data "aws_caller_identity" "current" {}

module "gsp-persistent" {
  source       = "git::https://github.com/alphagov/gsp-terraform-ignition//modules/gsp-persistent?ref=${var.gsp_version_ref}"
  cluster_name = "${module.gsp-network.cluster-name}"
  dns_zone     = "${var.dns_zone}"
}

module "gsp-network" {
  source       = "git::https://github.com/alphagov/gsp-terraform-ignition//modules/gsp-network?ref=${var.gsp_version_ref}"
  cluster_name = "${var.cluster_name}"
}

module "gsp-cluster" {
  source       = "git::https://github.com/alphagov/gsp-terraform-ignition//modules/gsp-cluster?ref=${var.gsp_version_ref}"
  account_name = "${var.account_name}"
  cluster_name = "${var.cluster_name}"
  dns_zone     = "${var.dns_zone}"

  admin_role_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/admin",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/deployer",
  ]

  sre_user_arns = [
    "arn:aws:iam::622626885786:user/daniel.blair@digital.cabinet-office.gov.uk"
  ]

  gds_external_cidrs = [
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
    "85.133.67.244/32",
    "18.130.144.30/32",  # autom8 concourse
    "3.8.110.67/32",     # autom8 concourse
  ]

  worker_instance_type = "${var.worker_instance_type}"
  worker_count         = "${var.worker_count}"
  ci_worker_instance_type = "${var.ci_worker_instance_type}"
  ci_worker_count         = "${var.ci_worker_count}"

  sealed_secrets_cert_pem        = "${module.gsp-persistent.sealed_secrets_cert_pem}"
  sealed_secrets_private_key_pem = "${module.gsp-persistent.sealed_secrets_private_key_pem}"
  vpc_id                         = "${module.gsp-network.vpc_id}"
  private_subnet_ids             = "${module.gsp-network.private_subnet_ids}"
  public_subnet_ids              = "${module.gsp-network.public_subnet_ids}"
  nat_gateway_public_ips         = "${module.gsp-network.nat_gateway_public_ips}"
  splunk_hec_url                 = "${var.splunk_hec_url}"
  splunk_hec_token               = "${var.splunk_hec_token}"
  splunk_index                   = "${var.splunk_index}"

  codecommit_init_role_arn = "${var.aws_account_role_arn}"
  github_client_id         = "${var.github_client_id}"
  github_client_secret     = "${var.github_client_secret}"
}

module "prototype-kit" {
  source = "git::https://github.com/alphagov/gsp-terraform-ignition//modules/flux-release?ref=${var.gsp_version_ref}"

  namespace      = "gsp-prototype-kit"
  chart_git      = "https://github.com/alphagov/gsp-govuk-prototype-kit.git"
  chart_ref      = "gsp"
  chart_path     = "charts/govuk-prototype-kit"
  cluster_name   = "${module.gsp-cluster.cluster-name}"
  cluster_domain = "${module.gsp-cluster.cluster-domain-suffix}"
  addons_dir     = "addons/${module.gsp-cluster.cluster-name}"

  values = <<EOF
    ingress:
      hosts:
        - pk.${module.gsp-cluster.cluster-domain-suffix}
        - prototype-kit.${module.gsp-cluster.cluster-domain-suffix}
      tls:
        - secretName: prototype-kit-tls
          hosts:
            - pk.${module.gsp-cluster.cluster-domain-suffix}
            - prototype-kit.${module.gsp-cluster.cluster-domain-suffix}
EOF
}

output "kubeconfig" {
  value = "${module.gsp-cluster.kubeconfig}"
}
