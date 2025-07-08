terraform {
required_version = ">= 1.0.0"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "1.54.1"
    }
  }
}

provider "openstack" {
  user_name   = "admin"
  tenant_name = "admin"
  password    = "test123"
  auth_url    = "http://211.183.3.10:5000/v3"
  region      = "RegionOne"
}
