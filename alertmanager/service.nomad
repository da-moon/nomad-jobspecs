
job "alertmanager" {
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
  group "alertmanager" {
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
    task "alertmanager" {
      driver = "docker"
      config {
        dns_servers         = [
          "172.17.0.1",
          "${attr.unique.network.ip-address}",
        ]
        dns_search_domains  = ["service.consul"]
        image = "prom/alertmanager:master"
        args = [
          "--log.level","debug",
          "--log.format","logfmt",
          "--config.file" , "/etc/alertmanager/config.yml",
          "--storage.path","data/",
          # [NOTE] => you might want to change retention policy
          "--data.retention","24h",
          "--web.listen-address","0.0.0.0:${NOMAD_PORT_alertmanager_ui}",
          # [QUESTION] => how to form HA cluster
          "--cluster.listen-address","0.0.0.0:${NOMAD_PORT_alertmanager_cluster}",
        ]
        volumes = [
          "local/alertmanager.yml:/etc/alertmanager/config.yml:ro",
        ]
      }
      resources {
        [[  if .service.cpu ]]cpu  = "[[.service.cpu]]"[[ end ]]
        memory  = "[[ or (.service.ram) "64" ]]"
        network {
          port "alertmanager_ui" {}
          port "alertmanager_cluster" {}
        }
      }
      logs {
        max_files     = "[[ or (.service.logs_max_files) "3" ]]"
        max_file_size = "[[ or (.service.logs_max_file_sizes) "1" ]]"
      }
    	kill_timeout = "3s"
      template {
        data = <<EOH
[[ fileContents "config/alertmanager.yml" ]]
EOH
        destination = "local/alertmanager.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      service {
        name = "alertmanager-svc"
        port = "alertmanager_ui"
        tags = [
          "prometheus",
          "alertmanager",
          "traefik.enable=true",
          "traefik.http.routers.alertmanager-svc.rule=Host(`alertmanager.[[.service.domain]]`)",
          "traefik.http.routers.alertmanager-svc.entrypoints=web,websecure",
          "traefik.http.services.alertmanager-svc.loadbalancer.sticky=true",
          "traefik.http.services.alertmanager-svc.loadbalancer.sticky.cookie.httponly=true",
          "traefik.http.services.alertmanager-svc.loadbalancer.sticky.cookie.samesite=strict",
        ]
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
