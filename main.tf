locals {
  context = var.context
}

module "keycloak_image" {
  source = "git::http://172.20.14.17/jiajian.chi/terraform-zstack-image.git?ref=v1.1.1"

  create_image        = true
  image_name          = var.image_name
  image_url           = var.image_url
  guest_os_type      = "Centos 7"
  platform           = "Linux"
  format             = "qcow2"
  architecture       = "x86_64"
  expunge            = var.expunge

  backup_storage_name = var.backup_storage_name
}

# 创建虚拟机实例
module "keycloak_instance" {
  source = "git::http://172.20.14.17/jiajian.chi/terraform-zstack-instance.git?ref=v1.1.1"

  name                  = var.instance_name
  description           = "Created by Terraform devops"
  instance_count        = 1
  image_uuid            = module.keycloak_image.image_uuid
  l3_network_name       = var.l3_network_name
  instance_offering_name = var.instance_offering_name
  expunge               = var.expunge
}

# 生成 docker-compose 文件
resource "local_file" "docker_compose" {
  content = templatefile("${path.module}/files/docker-compose.yaml.tpl", {
    admin_username = var.admin_username
    admin_password = var.admin_password
  })
  filename = "${path.module}/docker-compose.yaml"
}

# 生成 Keycloak 初始化脚本
resource "local_file" "init_script" {
  content = templatefile("${path.module}/scripts/init_idp.sh.tpl", {
    admin_username = var.admin_username
    admin_password = var.admin_password
  })
  filename = "${path.module}/initialize_keycloak.sh"
}

# 上传 docker-compose 文件到实例
resource "terraform_data" "remote_exec" {
  depends_on = [module.keycloak_instance, local_file.docker_compose, local_file.init_script]

  connection {
      type     = "ssh"
      host     = module.keycloak_instance.instance_ips[0]
      user     = var.ssh_user
      password = var.ssh_password
      timeout  = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/docker-compose.yaml"
    destination = "/root/docker-compose.yml"
    on_failure = fail
  }

  provisioner "file" {
    source      = "${path.module}/initialize_keycloak.sh"
    destination = "/root/initialize_keycloak.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Starting Keycloak services...'",
      "cd /root && docker compose up -d",

      "echo 'Waiting for services to start...'",
      "sleep 300",

      "echo 'Initializing Keycloak...'",
      "cd /root && bash ./initialize_keycloak.sh"

    ]
    on_failure = fail
  }

}


