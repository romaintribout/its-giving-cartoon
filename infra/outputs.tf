output "public_ip" {
  description = "Public IP address of the server."
  value       = openstack_networking_floatingip_v2.main.address
}
