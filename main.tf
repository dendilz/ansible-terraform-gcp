variable "hcloud_token" {}

variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "devs" {
  default = ["load-balancer", "static-site"]
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "aws" {
  region  = "us-west-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "hcloud_ssh_key" "rebrain_ssh_key" {
  name = "REBRAIN.SSH.PUB.KEY"
}

resource "hcloud_ssh_key" "danil_pub_key" {
  name       = "Danil.pub.key"
  public_key = file("~/.ssh/id_rsa_terraform.pub")
}

resource "hcloud_server" "rebrain" {
  count       = length(var.devs)
  name        = "${element(var.devs, count.index)}-${count.index}"
  image       = "ubuntu-18.04"
  server_type = "cx11"
  ssh_keys    = [data.hcloud_ssh_key.rebrain_ssh_key.name,
                 hcloud_ssh_key.danil_pub_key.id]
  labels = {
    "module" = "devops"
    "email"  = "dendilz_at_bk_ru"
  }
}

data "aws_route53_zone" "primary" {
  name = "devops.rebrain.srwx.net"
}

resource "aws_route53_record" "s53_record" {
  count   = length(var.devs)
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${element(hcloud_server.rebrain.*.name, count.index)}.${data.aws_route53_zone.primary.name}"
  type    = "A"
  ttl     = "300"
  records = [element(hcloud_server.rebrain.*.ipv4_address, count.index)]
}

resource "null_resource" "install_nginx" {
  provisioner "local-exec" {
    command = "ansible-playbook -i ./inventory ./install_nginx.yml"
  }
}
