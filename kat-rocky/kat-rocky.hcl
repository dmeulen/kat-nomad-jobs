job "kat-rocky" {
  datacenters = ["dev-kat"]
  update {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    auto_revert = true
  }
  group "kat-rocky" {
    count = 1
    constraint {
      operator = "distinct_hosts"
      value = "true"
    }
    volume "certs" {
      type = "host"
      source = "certs"
      read_only = true
    }
    network {
      port "http" {
        to = 8000
      }
      port "https" {}
      dns {
        servers = ["172.17.0.1"]
      }
    }
    service {
      port = "http"
      name = "rocky-http"
      check {
        type = "tcp"
        interval = "10s"
        timeout = "2s"
      }
    }
    task "kat-rocky" {
      driver = "docker"
      vault { policies = ["dev-kat-read-secrets"] }
      volume_mount {
        volume = "certs"
        destination = "/etc/ssl/certs"
      }
      template {
        destination = "secrets/kat-rocky.env"
        env = true
        data = <<EOD
{{- with secret "secret/kat/rocky" }}
SECRET_KEY={{ .Data.secret_key }}
{{- end }}
{{- with secret "secret/postgresql/users/rocky" }}
ROCKY_DB_HOST="postgresql.service.consul"
ROCKY_DB_PORT="5432"
ROCKY_DB="rocky"
ROCKY_DB_USER="rocky"
ROCKY_DB_PASSWORD="{{ .Data.password }}"
{{- end }}
{{- with secret "secret/kat/bytes" }}
BYTES_USERNAME="{{ .Data.username }}"
BYTES_PASSWORD="{{ .Data.password }}"
{{- end }}
{{- with secret "secret/postgresql/users/katalogus" }}
KATALOGUS_DB_URI="postgresql://katalogus:{{ .Data.password }}@postgresql.service.consul:5432/katalogus"
{{- end }}
{{- with secret "secret/users/rabbitmq/kat"}}
QUEUE_URI="amqp://kat:{{ .Data.password }}@rabbitmq.service.consul:5672/kat"
{{- end }}
KATALOGUS_API="http://katalogus-api.service.consul:7880"
OCTOPOES_API="http://octopoes-api.service.consul:8000"
BYTES_API="http://bytes-api.service.consul:7780"
SCHEDULER_API="http://scheduler-api.service.consul:7980"
DATABASE_MIGRATION="true"
EOD
      }
      config {
        image = "ghcr.io/minvws/nl-kat-rocky:container-image"
        ports = ["http"]
      }
      resources {
        cpu = 100
        memory = 512
      }
    }
  }
}
