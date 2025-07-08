variable "master_flavor_name" {
  description = "Flavor for the master node"
  default     = "m1.medium" 
}

variable "worker_flavor_name" {
  description = "Flavor for the worker nodes"
  default     = "m1.medium" 
}

variable "worker_count" {
  description = "Number of worker nodes"
  default     = 1
}
