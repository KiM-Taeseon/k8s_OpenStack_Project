resource "openstack_compute_secgroup_v2" "k8s_sg" {
  name        = "k8s-sg"
  description = "Security group for Kubernetes cluster"
}


# SSH 접속 허용 (모든 IP)
resource "openstack_networking_secgroup_rule_v2" "k8s_sg_rule_ssh" {
  direction         = "ingress" 
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_compute_secgroup_v2.k8s_sg.id
}

# Ping(ICMP) 허용 (모든 IP)
resource "openstack_networking_secgroup_rule_v2" "k8s_sg_rule_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_compute_secgroup_v2.k8s_sg.id
}


resource "openstack_networking_secgroup_rule_v2" "k8s_sg_rule_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = openstack_networking_subnet_v2.k8s_subnet.cidr 
  security_group_id = openstack_compute_secgroup_v2.k8s_sg.id
}

# Kube API Server 포트 허용 (모든 IP)
resource "openstack_networking_secgroup_rule_v2" "k8s_sg_rule_kube_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_compute_secgroup_v2.k8s_sg.id
}

# Kubelet 포트 허용 (모든 IP)
resource "openstack_networking_secgroup_rule_v2" "k8s_sg_rule_kubelet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_compute_secgroup_v2.k8s_sg.id
}

# NodePort 범위 허용 (모든 IP)
resource "openstack_networking_secgroup_rule_v2" "k8s_sg_rule_nodeport" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_compute_secgroup_v2.k8s_sg.id
}