resource "local_file" "AnsibleInventory" {
  content = templatefile("inventory.tmpl",
  {
   server_ip   = google_compute_instance.default.*.network_interface.0.access_config.0.nat_ip,
   domain_name = aws_route53_record.s53_record.*.name,
  }
  )
  filename = "inventory"
}
