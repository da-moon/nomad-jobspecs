job "mysql-server-raw-exec" {
  datacenters = ["dc1"]
  type        = "service"
  group "mysql-server-raw-exec" {
    count = 1
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      # => interval mode attempts to run again on the same node while
      # 'fail' might reschedule to another node.
      mode     = "delay"
    }
    ephemeral_disk {
      sticky  = true
      migrate = true
    }
    task "init" {
      driver = "raw_exec"
      resources {
        cpu    = 500
        memory = 1024
        network {
          mbits = 10
          port "db" {}
        }
      }
      config {
        command ="/bin/bash"
        args = ["/opt/mysql/scripts/mysql-init"]
      }
      lifecycle {
        sidecar = false
        hook = "prestart"
      }
    }
    task "run" {
      driver = "raw_exec"
      config {
        command ="/bin/bash"
        args = ["/opt/mysql/scripts/mysqld-wrapper"]
      }
      resources {
        cpu    = 500
        memory = 1024
        network {
          mbits = 10
          port "db" {}
        }
      }
      service {
        name = "mysql-server-raw-exec"
        port = "db"
        check {
          name     = "TCP Check"
          type     = "tcp"
          port     = "db"
          interval = "10s"
          timeout  = "2s"
        }
        check {
          name     = "Socket Check"
          type     = "script"
          command  = "/bin/bash"
          args     = ["/opt/mysql/scripts/health-check.sh"]
          interval = "5s"
          timeout  = "2s"
        }
      }
    }
  }
}

