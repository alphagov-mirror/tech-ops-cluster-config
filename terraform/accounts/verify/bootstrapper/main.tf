variable "aws_account_role_arn" {
  type = "string"
}

variable "cluster_state_bucket_name" {
  type = "string"
}

variable "cluster_state_bucket_key" {
  type = "string"
}

provider "aws" {
  region = "eu-west-2"
  assume_role {
    role_arn = "${var.aws_account_role_arn}"
  }
}

data "terraform_remote_state" "cluster" {
  backend = "s3"
  workspace = "verify"
  config {
    bucket = "${var.cluster_state_bucket_name}"
    key = "${var.cluster_state_bucket_key}"
    region = "eu-west-2"
  }
}

resource "local_file" "admin-kubeconfig" {
  filename = "kubeconfig"
  content  = "${data.terraform_remote_state.cluster.admin-kubeconfig}"
}

module "k8s-bootstrap" {
  source = "git::https://github.com/alphagov/gsp-terraform-ignition//modules/k8s-bootstrap?ref=4a1d85a89c7b10f25bb1a583eab4d4845d01db92"
  bootstrap_base_userdata_source       = "${data.terraform_remote_state.cluster.bootstrap-base-userdata-source}"
  bootstrap_base_userdata_verification = "${data.terraform_remote_state.cluster.bootstrap-base-userdata-verification}"
  user_data_bucket_name                = "${data.terraform_remote_state.cluster.user-data-bucket-name}"
  cluster_name                         = "${data.terraform_remote_state.cluster.cluster-name}"
  security_group_ids                   = ["${data.terraform_remote_state.cluster.controller-security-group-ids}"]
  subnet_id                            = "${data.terraform_remote_state.cluster.bootstrap-subnet-id}"
  iam_instance_profile_name            = "${data.terraform_remote_state.cluster.controller-instance-profile-name}"
  lb_target_group_arn                  = "${data.terraform_remote_state.cluster.apiserver-lb-target-group-arn}"
  dns_service_ip                       = "${data.terraform_remote_state.cluster.dns-service-ip}"
  cluster_domain_suffix                = "${data.terraform_remote_state.cluster.cluster-domain-suffix}"
  k8s_tag                              = "${data.terraform_remote_state.cluster.k8s-tag}"
  kubelet_kubeconfig                   = "${data.terraform_remote_state.cluster.kubelet-kubeconfig}"
  kube_ca_crt                          = "${data.terraform_remote_state.cluster.kube-ca-crt}"
}
