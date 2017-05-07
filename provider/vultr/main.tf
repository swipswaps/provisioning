variable "token" {}

variable "hosts" {
  default = 0
}

variable "hostname_format" {
  type = "string"
}

variable "region" {
  type    = "string"
  default = "9"
}

variable "plan" {
  type    = "string"
  default = "201"
}

variable "image" {
  type    = "string"
  default = "215"
}

variable "ssh_keys" {
  type = "list"
}

variable "loopback_storage_size_gb" {
  default = 10
}

variable "private_network_interface" {
  default = "ens7"
}

resource "local_file" "dummy" {
  content  = ""
  filename = "/tmp/dummy"
}

data "external" "vultr_server" {
  count = "${var.hosts}"

  depends_on = ["local_file.dummy"]

  program = ["sh", "${path.module}/scripts/create.sh"]

  query = {
    token    = "${var.token}"
    region   = "${var.region}"
    plan     = "${var.plan}"
    image    = "${var.image}"
    ssh_keys = "${join(",", var.ssh_keys)}"
    name     = "${format(var.hostname_format, count.index + 1)}"
  }
}

data "external" "vultr_host" {
  count = "${var.hosts}"

  depends_on = ["data.external.vultr_server"]

  program = ["sh", "${path.module}/scripts/setup.sh"]

  query = {
    token = "${var.token}"
    id    = "${lookup(data.external.vultr_server.*.result[count.index], "id")}"
  }
}

resource "null_resource" "setup" {
  count = "${var.hosts}"

  connection {
    host  = "${lookup(data.external.vultr_host.*.result[count.index], "public_ip")}"
    user  = "root"
    agent = true
  }

  provisioner "remote-exec" {
    inline = "echo '${element(data.template_file.interfaces.*.rendered, count.index)}' >> /etc/network/interfaces; ifup ${var.private_network_interface}"
  }

  provisioner "remote-exec" {
    inline = [
      "dd if=/dev/zero of=/storage bs=1024 count=0 seek=$(echo 1024*1024*${var.loopback_storage_size_gb} | bc)",
      "losetup /dev/loop0 /storage"
    ]
  }
}

data "template_file" "interfaces" {
  count = "${var.hosts}"

  template = "${file("${path.module}/templates/interfaces")}"

  vars {
    private_network_interface = "${var.private_network_interface}"
    private_ip                = "${element(data.template_file.private_ips.*.rendered, count.index)}"
  }
}

data "template_file" "private_ips" {
  count = "${var.hosts}"

  template = "$${ip}"

  vars {
    ip = "${cidrhost("${lookup(data.external.vultr_host.*.result[0], "private_ip")}/24", count.index + 1)}"
  }
}

output "ids" {
  value = ["${data.external.vultr_server.*.result.id}"]
}

output "hostnames" {
  value = ["${data.external.vultr_host.*.result.name}"]
}

output "public_ips" {
  value = ["${data.external.vultr_host.*.result.public_ip}"]
}

output "private_ips" {
  value = ["${data.template_file.private_ips.*.rendered}"]
}

output "private_network_interface" {
  value = "${var.private_network_interface}"
}
