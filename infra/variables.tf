variable "region" {
  description = "OpenStack region."
  type        = string
  default     = "dc3-a"
}

variable "flavor" {
  description = "Instance flavor (2 vCPU, 4 GB RAM by default)."
  type        = string
  default     = "a2-ram4-disk20-perf1"
}

variable "image" {
  description = "Image name for the VM."
  type        = string
  default     = "Ubuntu 24.04 LTS Noble Numbat"
}

variable "external_network" {
  description = "Name of the external network used for the router and floating IP."
  type        = string
  default     = "ext-floating1"
}

variable "volume_size" {
  description = "Size of the data volume, in GB."
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "SSH public key installed on the VM."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR ranges allowed to connect on SSH (TCP 22)."
  type        = list(string)
}
