# 외부 네트워크(extnet) 정보 가져오기
data "openstack_networking_network_v2" "extnet" {
  name     = "extnet"
  external = true
}

# SSH 키 페어 생성
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.root}/../ssh_key"
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.root}/../ssh_key.pub"
  file_permission = "0644"
}

resource "openstack_compute_keypair_v2" "k8s_keypair" {
  name       = "k8s-keypair"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# 내부 네트워크 생성
resource "openstack_networking_network_v2" "k8s_network" {
  name           = "k8s-net"
  admin_state_up = "true"
}

# 내부 서브넷 생성
resource "openstack_networking_subnet_v2" "k8s_subnet" {
  name       = "k8s-subnet"
  network_id      = openstack_networking_network_v2.k8s_network.id
  cidr       = "10.0.1.0/24"
  ip_version = 4
  dns_nameservers = ["8.8.8.8"]
}

# 라우터 생성 및 외부 게이트웨이 설정
resource "openstack_networking_router_v2" "k8s_router" {
  name                = "k8s-router"
  admin_state_up      = true
  external_gateway    = data.openstack_networking_network_v2.extnet.id
}

# 라우터에 내부 서브넷 연결
resource "openstack_networking_router_interface_v2" "k8s_router_interface" {
  router_id = openstack_networking_router_v2.k8s_router.id
  subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
}



# 마스터 노드
resource "openstack_compute_instance_v2" "k8s_master" {
  name              = "k8s-master"
  image_id          = "3a3f260a-dd93-4531-a781-f4eb0f53709f" # basic과 같은 이미지 ID 사용
  flavor_name       = var.master_flavor_name
  key_pair          = openstack_compute_keypair_v2.k8s_keypair.name 
  security_groups   = [openstack_compute_secgroup_v2.k8s_sg.name]

  network {
    uuid = openstack_networking_network_v2.k8s_network.id
  }

  lifecycle {
    create_before_destroy = true
  }

   depends_on = [
    openstack_networking_router_interface_v2.k8s_router_interface
  ]
}

# 마스터 노드에 Floating IP 할당
resource "openstack_networking_floatingip_v2" "master_fip" {
  pool = "extnet"
}

resource "openstack_compute_floatingip_associate_v2" "master_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.master_fip.address
  instance_id = openstack_compute_instance_v2.k8s_master.id
}

# 워커 노드
resource "openstack_compute_instance_v2" "k8s_worker" {
  count             = var.worker_count
  name              = "k8s-worker-${count.index}"
  image_id          = "3a3f260a-dd93-4531-a781-f4eb0f53709f"
  flavor_name       = var.worker_flavor_name
  key_pair          = openstack_compute_keypair_v2.k8s_keypair.name
  security_groups   = [openstack_compute_secgroup_v2.k8s_sg.name]

  network {
    uuid = openstack_networking_network_v2.k8s_network.id
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    openstack_networking_router_interface_v2.k8s_router_interface
  ]
}


# 워커 노드들에 Floating IP 할당
resource "openstack_networking_floatingip_v2" "worker_fips" {
  count = var.worker_count
  pool  = "extnet"
}

resource "openstack_compute_floatingip_associate_v2" "worker_fip_assoc" {
  count       = var.worker_count
  floating_ip = openstack_networking_floatingip_v2.worker_fips[count.index].address
  instance_id = openstack_compute_instance_v2.k8s_worker[count.index].id
}


# # 결과 확인
# output "공인IP" {
#   value = openstack_networking_floatingip_v2.fip_1.address
# }
