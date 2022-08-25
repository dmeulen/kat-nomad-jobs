job "kat-ocotpoes-api-worker" {
  datacenters = ["dev-kat"]
  update {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    auto_revert = true
  }
  group "kat-ocotpoes-api-worker" {
    count = 1
    volume "certs" {
      type = "host"
      source = "certs"
      read_only = true
    }
    network {
      dns {
        servers = ["172.17.0.1"]
      }
    }
    task "kat-ocotpoes-api-worker" {
      driver = "docker"
      vault { policies = ["dev-kat-read-secrets"] }
      volume_mount {
        volume = "certs"
        destination = "/etc/ssl/certs"
      }
      template {
        destination = "secrets/kat-ocotpoes-api-worker.env"
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
        command = "/usr/local/bin/celery"
        args = [
          "-A", "octopoes.tasks.tasks", "worker",
          "--loglevel=INFO"
        ]
        network_mode = "host"
      }
      resources {
        cpu = 100
        memory = 256
      }
    }
  }
}
