data "openstack_networking_network_v2" "external" {
  name     = var.external_network
  region   = var.region
  external = true
}

resource "openstack_compute_keypair_v2" "main" {
  name       = "its-giving-cartoon"
  region     = var.region
  public_key = var.ssh_public_key
}

# Network

resource "openstack_networking_network_v2" "main" {
  name           = "its-giving-cartoon"
  region         = var.region
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "main" {
  name            = "its-giving-cartoon"
  region          = var.region
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.0.0/24"
  ip_version      = 4
  dns_nameservers = ["1.1.1.1", "8.8.8.8"]
}

resource "openstack_networking_router_v2" "main" {
  name                = "its-giving-cartoon"
  region              = var.region
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "main" {
  region    = var.region
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.main.id
}

# Security group: SSH only, from the allowed CIDRs. Default egress rules are kept.

resource "openstack_networking_secgroup_v2" "main" {
  name        = "its-giving-cartoon"
  region      = var.region
  description = "SSH from allowed CIDRs only"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  for_each = toset(var.ssh_allowed_cidrs)

  region            = var.region
  security_group_id = openstack_networking_secgroup_v2.main.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
}

# Server

resource "openstack_compute_instance_v2" "main" {
  name            = "its-giving-cartoon"
  region          = var.region
  image_name      = var.image
  flavor_name     = var.flavor
  key_pair        = openstack_compute_keypair_v2.main.name
  security_groups = [openstack_networking_secgroup_v2.main.name]

  network {
    uuid = openstack_networking_network_v2.main.id
  }

  # The subnet must exist before the VM gets a port on the network.
  depends_on = [openstack_networking_subnet_v2.main]

  # The server-power workflow stops and starts the VM; don't undo that on apply.
  lifecycle {
    ignore_changes = [power_state]
  }
}

# Data volume, kept separate from the VM so the VM can be replaced without losing data.
# To delete it on purpose, remove prevent_destroy in a PR first.

resource "openstack_blockstorage_volume_v3" "data" {
  name   = "its-giving-cartoon-data"
  region = var.region
  size   = var.volume_size

  lifecycle {
    prevent_destroy = true
  }
}

resource "openstack_compute_volume_attach_v2" "data" {
  region      = var.region
  instance_id = openstack_compute_instance_v2.main.id
  volume_id   = openstack_blockstorage_volume_v3.data.id
}

# Public IP

resource "openstack_networking_floatingip_v2" "main" {
  region = var.region
  pool   = var.external_network
}

data "openstack_networking_port_v2" "main" {
  region     = var.region
  device_id  = openstack_compute_instance_v2.main.id
  network_id = openstack_networking_network_v2.main.id
}

resource "openstack_networking_floatingip_associate_v2" "main" {
  region      = var.region
  floating_ip = openstack_networking_floatingip_v2.main.address
  port_id     = data.openstack_networking_port_v2.main.id

  # The router must be connected to the subnet before a floating IP can be associated.
  depends_on = [openstack_networking_router_interface_v2.main]
}
