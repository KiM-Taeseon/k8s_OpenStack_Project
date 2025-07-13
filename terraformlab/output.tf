output "master_ip" {
  value = openstack_networking_floatingip_v2.master_fip.address
}

output "worker_ips" {
  value = openstack_networking_floatingip_v2.worker_fips[*].address
}

output "master_private_ip" {
  value = openstack_compute_instance_v2.k8s_master.access_ip_v4
}

output "worker_private_ips" {
  value = openstack_compute_instance_v2.k8s_worker[*].network[0].fixed_ip_v4
}

output "ssh_private_key_path" {
  value = abspath("${path.root}/../ssh_key")
}