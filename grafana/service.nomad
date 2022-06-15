# [WARN] => right now, there is no git token in vault cluster for this repo so this job fails
job "grafana" {
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
  group "grafana" {
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
    network {
      port  "grafana_ui" {}
      dns {
        servers =  [
          "172.17.0.1",
          "${attr.unique.network.ip-address}",
        ]
        searches= ["service.consul"]
      }
    }
    # [NOTE] => https://github.com/hashicorp/nomad/issues/3854
    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:master"
        volumes = [
          "local/grafana:/etc/grafana",
        ]
        ports=["grafana_ui"]
      }
      env {
        GF_INSTALL_PLUGINS         = "grafana-piechart-panel"
        GF_SERVER_HTTP_PORT        = "${NOMAD_PORT_grafana_ui}"
        GF_LOG_LEVEL               = "info"
        GF_AUTH_ANONYMOUS_ENABLED  = "yes"
      }
      template {
        data = <<EOH
[[ fileContents "config/provisioning/datasources/prometheus.yml.tpl" ]]
EOH
        destination = "local/grafana/provisioning/datasources/prometheus.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      template {
        data = <<EOH
[[ fileContents "config/grafana.ini" ]]
EOH
        destination = "local/grafana/grafana.ini"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        left_delimiter = "{{|"
        right_delimiter = "|}}"
      }

      template {
        data = <<EOH
[[ fileContents "config/provisioning/dashboards/traefik.json" ]]
EOH
        destination = "local/grafana/provisioning/dashboards/traefik.json"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        left_delimiter = "{{|"
        right_delimiter = "|}}"
      }
      template {
        data = <<EOH
[[ fileContents "config/provisioning/dashboards/dashboards.yml" ]]
EOH
        destination = "local/grafana/provisioning/dashboards/dashboards.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        left_delimiter = "{{|"
        right_delimiter = "|}}"
      }
      template {
        data = <<EOH
[[ fileContents "config/provisioning/dashboards/nomad-cluster.json" ]]
EOH
        destination = "local/grafana/provisioning/dashboards/nomad-cluster.json"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        left_delimiter = "{{|"
        right_delimiter = "|}}"
      }
      template {
        data = <<EOH
[[ fileContents "config/provisioning/dashboards/nomad-jobs.json" ]]
EOH
        destination = "local/grafana/provisioning/dashboards/nomad-jobs.json"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        left_delimiter = "{{|"
        right_delimiter = "|}}"
      }
      template {
        data = " "
        destination = "local/grafana/provisioning/plugins/.gitkeep"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      template {
        data = " "
        destination = "local/grafana/provisioning/notifiers/.gitkeep"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      resources {
        [[  if .service.cpu ]]cpu  = "[[.service.cpu]]"[[ end ]]
        memory  = "[[ or (.service.ram) "64" ]]"
      }
      logs {
        max_files     = "[[ or (.service.logs_max_files) "3" ]]"
        max_file_size = "[[ or (.service.logs_max_file_sizes) "1" ]]"
      }
    	kill_timeout = "3s"
    }
    service {
      name = "grafana-svc"
      port = "grafana_ui"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana-svc.rule=Host(`grafana.[[.service.domain]]`)",
        "traefik.http.routers.grafana-svc.entrypoints=web,websecure",
        "traefik.http.services.grafana-svc.loadbalancer.sticky=true",
        "traefik.http.services.grafana-svc.loadbalancer.sticky.cookie.httponly=true",
        "traefik.http.services.grafana-svc.loadbalancer.sticky.cookie.samesite=strict",
     ]
      check {
        type     = "http"
        port ="grafana_ui"  
        path     = "/api/health"
        interval = "10s"
        timeout  = "2s"
        check_restart {
          limit           = 2
          grace           = "60s"
          ignore_warnings = false
        }
      }
    }
  }
}

