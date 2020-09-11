resource "local_file" "AnsibleInventory" {
  content = templatefile("inventory.tmpl",
  {
   server_ip   = hcloud_server.rebrain.*.ipv4_address,
   domain_name = aws_route53_record.s53_record.*.name,
  }
  )
  filename = "inventory"
}
