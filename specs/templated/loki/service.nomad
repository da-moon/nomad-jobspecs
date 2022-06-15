job "loki" {
  type="service" 
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
  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }[[ if .service.node_class]]
  constraint {
    attribute = "${node.class}"
    value     = "[[.service.node_class]]"
  }[[end]]
  group "loki" {
    count = "[[ or (.service.count) "1" ]]"
    ephemeral_disk {
      size    = "[[ or (.service.disk_size) "300" ]]"
      migrate = true
    }
    restart {
      attempts = 3
      interval = "2m"
      delay    = "15s"
      mode     = "fail"
    }
    task "loki" {
      driver = "docker"
      config {
        dns_servers         = [
          "172.17.0.1",
          "${attr.unique.network.ip-address}",
        ]
        dns_search_domains  = ["service.consul"]
        image = "grafana/loki:master"
        args = [
          "--log.level","debug",
          "--config.file","/etc/loki/config/loki.yml",
        ]
        volumes = [
        "local/config:/etc/loki/config",
        ]
      }
      template {
        change_mode   = "signal"
        change_signal = "SIGHUP"
        data        = <<EOH
[[ fileContents "config/prometheus.yml" ]]
EOH
        destination   = "local/config/loki.yml"
      }
      resources {
        [[  if .service.cpu ]]cpu  = "[[.service.cpu]]"[[ end ]]
        memory  = "[[ or (.service.ram) "64" ]]"
        network {
          port  "loki_ui" {}
        }
      }
      logs {
        max_files     = "[[ or (.service.logs_max_files) "3" ]]"
        max_file_size = "[[ or (.service.logs_max_file_sizes) "1" ]]"
      }
    	kill_timeout = "3s"
      service {
        name = "loki-service"
        port = "loki_ui"
        tags =[
          "loki",
          "prometheus",
        ]
        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
