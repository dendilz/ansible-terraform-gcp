variable "aws_access_key" {}

variable "aws_secret_key" {}

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

resource "google_compute_global_address" "my_address" {
  name = "dendilz-at-bk-ru"
}

data "aws_route53_zone" "primary" {
  name = "devops.rebrain.srwx.net"
}

resource "aws_route53_record" "s53_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${google_compute_global_address.my_address.name}.${data.aws_route53_zone.primary.name}"
  type    = "A"
  ttl     = "300"
  records = [google_compute_global_address.my_address.address]
}

resource "google_compute_global_forwarding_rule" "my_rule" {
  name       = "dendilz-at-bk-ru-port-80"
  ip_address = google_compute_global_address.my_address.address
  port_range = "80"
  target     = google_compute_target_http_proxy.my_proxy.self_link
}

resource "google_compute_target_http_proxy" "my_proxy" {
  name    = "dendilz-at-bk-ru"
  url_map = google_compute_url_map.my_url_map.self_link
}

resource "google_compute_url_map" "my_url_map" {
  name            = "dendilz-at-bk-ru"
  default_service = google_compute_backend_service.my_service.self_link
}

resource "google_compute_backend_service" "my_service" {
  name          = "dendilz-at-bk-ru"
  protocol      = "HTTP"
  health_checks = [google_compute_http_health_check.default.id]

  backend {
    group = google_compute_instance_group.webserver.id
  }
}

resource "google_compute_http_health_check" "default" {
  name         = "dendilz-at-bk-ru"
  request_path = "/health"

  timeout_sec        = 5
  check_interval_sec = 5
  port               = 1337

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group" "webserver" {
  name        = "dendilz-at-bk-ru"
  description = "Terraform test instance group"

  instances = [
    google_compute_instance.default.id,
  ]

  named_port {
    name = "http"
    port = "80"
  }

  zone = "us-central1-c"
}

resource "google_compute_instance" "default" {
  name         = "dendilz-at-bk-ru"
  machine_type = "f1-micro"
  zone         = "us-central1-c"

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
  allow {
    protocol = "tcp"
    ports    = ["1337"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22", "209.85.152.0/22", "209.85.204.0/22"]
}

resource "null_resource" "install_nginx" {
  provisioner "local-exec" {
    command = "ansible-playbook -i ./inventory ./install_nginx.yml"
  }
  depends_on = [
    aws_route53_record.s53_record
  ]
}
