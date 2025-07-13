variable "master_flavor_name" {
  description = "Flavor for the master node"
  default     = "t2.medium" 
}

variable "worker_flavor_name" {
  description = "Flavor for the worker nodes"
  default     = "t2.medium" 
}

variable "worker_count" {
  description = "Number of worker nodes"
  default     = 1
}
