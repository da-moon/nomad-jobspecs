job "node-exporter" {
  type = "system"
  [[ if .service.datacenters ]]datacenters =  [ [[range $index, $value := .service.datacenters ]][[if ne $index 0]],[[end]]"[[$value]]"[[end]] ][[ else ]]datacenters = [ "[[ or (env "DC") "dc1" ]]" ][[ end ]]
  [[ if .service.namespace ]]namespace = "[[.service.namespace]]"[[end]]
  [[ if .service.canary ]]# [NOTE] => canary deploy  
  update {
    auto_revert       = true
    max_parallel      = 1 
    canary            = 1 
    progress_deadline = "0"
    stagger = "2m"
    healthy_deadline  = "1m" 
    min_healthy_time  = "15s"
  }[[ else ]] # [NOTE] => rolling release
  update {
    max_parallel = 1
    min_healthy_time = "15s"
    healthy_deadline = "1m"
    auto_revert = true
    canary = 0
  }[[ end ]]
  [[ if .service.node_class]]
  constraint {
    attribute = "${node.class}"
    value     = "[[.service.node_class]]"
  }[[end]]
  group "node-exporter" {
    count = "[[ or (.service.count) "1" ]]"
    ephemeral_disk {
      size    = "[[ or (.service.disk_size) "300" ]]"
      migrate = true
    }
    network {
      dns {
        servers =  [
          "172.17.0.1",
          "${attr.unique.network.ip-address}",
        ]
        searches= ["service.consul"]
      }
    }
    task "node-exporter" {
      # [NOTE] => Do not use docker driver here since it seems like it cannot read system information.      
      driver = "raw_exec"
      artifact {
        source = "https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz"
      }
      config {
        command = "node_exporter-1.0.1.linux-amd64/node_exporter"
        args = [
          "--collector.systemd",
          "--collector.processes",
          "--log.level","debug",
          "--log.format","logfmt",
          "--web.listen-address",":${NOMAD_PORT_node_exporter}",
        ]
      }
      resources {
        [[  if .service.cpu ]]cpu  = "[[.service.cpu]]"[[ end ]]
        memory  = "[[ or (.service.ram) "64" ]]"
        network {
          port "node_exporter" {}
        }
      }
      logs {
        max_files     = "[[ or (.service.logs_max_files) "3" ]]"
        max_file_size = "[[ or (.service.logs_max_file_sizes) "1" ]]"
      }
    	kill_timeout = "3s"
      service {
        address_mode="host"
        name = "node-exporter-svc"
        port = "node_exporter"
        tags = [
          "prometheus",
          "node-exporter",
        ]
        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
          port     = "node_exporter"
          address_mode="host"
        }
      }
    }
  }
}
