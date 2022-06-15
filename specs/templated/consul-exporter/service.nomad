
job "consul-exporter" {
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
  group "consul-exporter" {
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
    task "consul-exporter" {
      driver = "docker"
      config {
        dns_servers         = [
          "172.17.0.1",
          "${attr.unique.network.ip-address}",
        ]
        dns_search_domains  = ["service.consul"]
        image = "prom/consul-exporter:master"
        args = [
          # => [FIXME] this can lead to security issues
          "--consul.insecure",
          "--consul.health-summary",
          "--log.level","debug",
          "--log.format","logfmt",
          #"--consul.server","https://consul:8501",
          "--consul.server","https://${attr.unique.network.ip-address}:8501",
          "--web.listen-address",":${NOMAD_PORT_consul_exporter}",
        ]
      }
      resources {
        [[  if .service.cpu ]]cpu  = "[[.service.cpu]]"[[ end ]]
        memory  = "[[ or (.service.ram) "64" ]]"
        network {
          port "consul_exporter" {}
        }
      }
      logs {
        max_files     = "[[ or (.service.logs_max_files) "3" ]]"
        max_file_size = "[[ or (.service.logs_max_file_sizes) "1" ]]"
      }
      kill_timeout = "3s"
      # [NOTE] => services 
      service {
        name = "consul-exporter-svc"
        port = "consul_exporter"
        tags = [
          "prometheus",
          "consul-exporter",
        ]
        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
        check {
          name = "alive"
          port = "consul_exporter"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }
  }
}
