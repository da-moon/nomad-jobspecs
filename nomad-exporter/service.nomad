
job "nomad-exporter" {
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
  group "nomad-exporter" {
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
    task "nomad-exporter" {
      driver = "docker"
      config{
        dns_servers         = [
          "172.17.0.1",
          "${attr.unique.network.ip-address}",
        ]
        dns_search_domains  = ["service.consul"]
        image = "registry.gitlab.com/yakshaving.art/nomad-exporter:latest"
        args = [
          "--debug",
          "--tls.insecure",
          "--allow-stale-reads",
          #"--nomad.address","https://nomad:4646",
          "--nomad.address","https://${attr.unique.network.ip-address}:4646",
          "--web.listen-address",":${NOMAD_PORT_nomad_exporter}",
        ]
      }
      resources {
        [[  if .service.cpu ]]cpu  = "[[.service.cpu]]"[[ end ]]
        memory  = "[[ or (.service.ram) "64" ]]"
        network {
          port "nomad_exporter" {}
        }
      }
      logs {
        max_files     = "[[ or (.service.logs_max_files) "3" ]]"
        max_file_size = "[[ or (.service.logs_max_file_sizes) "1" ]]"
      }
      # [NOTE] => services 
      service {
        name = "nomad-exporter-svc"
        tags = [
          "prometheus",
          "nomad-exporter",
        ]
        port = "nomad_exporter"
        check {
          type     = "http"
          path     = "/-/status"
          interval = "10s"
          timeout  = "2s"
        }
        check {
          name = "alive"
          port = "nomad_exporter"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    	kill_timeout = "3s"
    }
  }
}
