variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "devs" {
  default = ["load-balancer", "static-site"]
}

provider "aws" {
  region     = "us-west-2"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "google" {
  credentials = file("key.json")
  region      = "us-central1"
  zone        = "us-central1-c"
  project     = "rebrain"
}

resource "google_compute_instance" "default" {
  count        = length(var.devs)
  name         = "${element(var.devs, count.index)}-${count.index}"
  machine_type = "f1-micro"
  zone         = "us-west1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-lts"
    }
  }

  network_interface {
    network = "default" 
 
    access_config {
    }
  }
 
  metadata = {
    ssh-keys = "devopbyrebrain:${file("~/.ssh/id_rsa_terraform.pub")}"
  }
}

resource "google_compute_firewall" "http-server" {
  name    = "rebrain-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

data "aws_route53_zone" "primary" {
  name = "devops.rebrain.srwx.net"
}

resource "aws_route53_record" "s53_record" {
  count   = length(var.devs)
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${element(google_compute_instance.default.*.name, count.index)}.${data.aws_route53_zone.primary.name}"
  type    = "A"
  ttl     = "300"
  records = [element(google_compute_instance.default.*.network_interface.0.access_config.0.nat_ip, count.index)]
}

resource "null_resource" "install_nginx" {
  provisioner "local-exec" {
    command = "ansible-playbook -i ./inventory ./install_nginx.yml"
  }
  depends_on = [
    aws_route53_record.s53_record
  ]
}
