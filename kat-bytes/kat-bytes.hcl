job "kat-bytes" {
  datacenters = ["dev-kat"]
  update {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    auto_revert = true
  }
  group "kat-bytes" {
    count = 1
    ephemeral_disk {
      migrate = true
      sticky = true
      size = "1024"
    }
    volume "certs" {
      type = "host"
      source = "certs"
      read_only = true
    }
    network {
      port "api" {
        static = 7780
        to = 8000
      }
      dns {
        servers = ["172.17.0.1"]
      }
    }
    service {
      port = "api"
      name = "bytes-api"
      check {
        type = "tcp"
        interval = "10s"
        timeout = "2s"
      }
    }
    task "kat-bytes" {
      driver = "docker"
      vault { policies = ["dev-kat-read-secrets"] }
      volume_mount {
        volume = "certs"
        destination = "/etc/ssl/certs"
      }
      template {
        destination = "secrets/kat-bytes.env"
        env = true
        data = <<EOD
{{- with secret "secret/kat/bytes" }}
SECRET="{{ .Data.jwt }}"
BYTES_USERNAME="{{ .Data.username }}"
BYTES_PASSWORD="{{ .Data.password }}"
{{- end }}
{{- with secret "secret/postgresql/users/bytes" }}
BYTES_DB_URI="postgresql://bytes:{{ .Data.password }}@postgresql.service.consul:5432/bytes"
{{- end }}
{{- with secret "secret/users/rabbitmq/kat"}}
QUEUE_URI="amqp://kat:{{ .Data.password }}@rabbitmq.service.consul:5672/kat"
{{- end }}
BYTES_DATA_DIR="/local/bytes_data"
ENCRYPTION_MIDDLEWARE="IDENTITY"
DATABASE_MIGRATION="true"
EOD
      }
      config {
        image = "ghcr.io/minvws/nl-kat-bytes:container-image"
        ports = ["api"]
      }
      resources {
        cpu = 100
        memory = 256
      }
    }
  }
}
