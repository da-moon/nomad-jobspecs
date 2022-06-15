job "mysql-server-docker" {
  datacenters = ["dc1"]
  type        = "service"
  # => prevent the scheduler from
  # co-locate any group in this job on the same machine
  constraint {
    distinct_hosts = true
  }

  group "mysql-server-docker" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    ephemeral_disk {
      # => Specifies that Nomad should make a best-effort attempt to 
      # place the updated allocation on the same machine
      # => [NOTE] setting sticky to true would enable sticky volumes 
      sticky  = true
      # => When sticky is true, this specifies that
      # the Nomad client should make a best-effort attempt to migrate the
      # data from a remote machine if placement cannot be made on the original node
      # => migrations are atomic
      migrate = true
    }
    volume "mysql-data" {
      # => allows read and write
      read_only = false
      # => use client -> host_volume stanza to customize where the files are stored
      type      = "host"
      source    = "mysql-data-dockerized"
    }
    volume "mysql-log" {
      read_only = false
      type      = "host"
      source    = "mysql-log-dockerized"
    }
    volume "mysql-conf" {
      read_only = false
      type      = "host"
      source    = "mysql-conf-dockerized"
    }
    task "run" {
      driver = "docker"
      config {
        image = "mysql/mysql-server:8.0"
        port_map {
          db = 3306
        }
      }
      # => location inside the container 'mysql' volume is mounted
      volume_mount {
        volume      = "mysql-data"
        destination = "/var/lib/mysql"
        read_only   = false
      }
      volume_mount {
        volume      = "mysql-log"
        destination = "/var/log/mysql"
        read_only   = false
      }
      volume_mount {
        volume      = "mysql-conf"
        destination = "/etc/mysql/conf.d"
        read_only   = false
      }
      # cgroup constraints
      resources {
        cpu    = 500
        memory = 1024
        network {
          mbits = 10
          port "db" {}
        }
      }
      env {
        "MYSQL_ALLOW_EMPTY_PASSWORD" = "yes"
        "MYSQL_ROOT_PASSWORD" = "password"
        "MYSQL_USER" = "root" 
      }
      service {
        name = "mysql-server-docker"
        port = "db"
        # health-check
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}

