job "kat-octopoes-api" {
  datacenters = ["dev-kat"]
  update {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    auto_revert = true
  }
  group "kat-octopoes-api" {
    count = 1
    volume "certs" {
      type = "host"
      source = "certs"
      read_only = true
    }
    network {
      port "api" {
        static = 8000
      }
      dns {
        servers = ["172.17.0.1"]
      }
    }
    service {
      port = "api"
      name = "octopoes-api"
      check {
        type = "tcp"
        interval = "10s"
        timeout = "2s"
      }
    }
    task "kat-octopoes-api" {
      driver = "docker"
      vault { policies = ["dev-kat-read-secrets"] }
      volume_mount {
        volume = "certs"
        destination = "/etc/ssl/certs"
      }
      template {
        destination = "secrets/kat-octopoes-api.env"
        env = true
        data = <<EOD
XTDB_URI="http://xtdb.service.consul:3000"
{{- with secret "secret/users/rabbitmq/kat"}}
QUEUE_URI="amqp://kat:{{ .Data.password }}@rabbitmq.service.consul:5672/kat"
{{- end }}
EOD
      }
      config {
        image = "ghcr.io/minvws/nl-kat-octopoes:container-image"
        network_mode = "host"
        ports = ["api"]
      }
      resources {
        cpu = 100
        memory = 64
      }
    }
  }
}
