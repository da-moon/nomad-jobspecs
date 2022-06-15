#levant render -var-file=vars.yml -out=rendered.nomad service.nomad
job "prometheus" {
  [[  if .service.datacenters ]]datacenters =  [ [[range $index, $value := .service.datacenters ]][[if ne $index 0]],[[end]]"[[$value]]"[[end]] ][[ else ]]datacenters = [ "[[ or (env "DC") "dc1" ]]" ][[ end ]]
  namespace = "[[.service.namespace]]"
  type="service" 
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
  group "prometheus" {
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
    task "prometheus" {
      driver = "docker"
      config {
        image = "prom/prometheus:master"
        dns_servers         = [
          "172.17.0.1",
          "${attr.unique.network.ip-address}",
        ]
        dns_search_domains  = ["service.consul"]
        args = [
          "--log.level","debug",
          "--log.format","logfmt",
          "--config.file" , "/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path","/prometheus/data",
          # [NOTE] => default : 2h
          "--storage.tsdb.min-block-duration", "10m",
          # [NOTE] => default : 15d
          "--storage.tsdb.retention.time", "1d",
          "--web.listen-address","0.0.0.0:${NOMAD_PORT_prometheus_ui}",
        ]
        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml:ro",
        ]
      }
      resources {
        [[  if .service.cpu ]]cpu  = "[[.service.cpu]]"[[ end ]]
        memory  = "[[ or (.service.ram) "300" ]]"
        network {
          port "prometheus_ui" {}
        }
      }
      logs {
        max_files     = "[[ or (.service.logs_max_files) "3" ]]"
        max_file_size = "[[ or (.service.logs_max_file_sizes) "1" ]]"
      }
      kill_timeout = "3s"
      // vault {
      //   namespace = "[[.service.namespace]]"
      //   policies      = ["prometheus"]
      //   change_mode   = "signal"
      //   change_signal = "SIGHUP"
      // }
      template {
        data = <<EOH
[[ fileContents "config/prometheus.yml" ]]
EOH
        destination = "local/prometheus.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      service {
        name = "prometheus-svc"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus-svc.rule=Host(`prometheus.[[.service.domain]]`)",
          "traefik.http.routers.prometheus-svc.entrypoints=web,websecure",
          "traefik.http.services.prometheus-svc.loadbalancer.sticky=true",
          "traefik.http.services.prometheus-svc.loadbalancer.sticky.cookie.httponly=true",
          "traefik.http.services.prometheus-svc.loadbalancer.sticky.cookie.samesite=strict",
          "traefik.http.services.prometheus-svc.loadbalancer.sticky.cookie.secure=true",
        ]
        port = "prometheus_ui"
        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
