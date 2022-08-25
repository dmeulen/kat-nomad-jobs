job "kat-scheduler" {
  datacenters = ["dev-kat"]
  update {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    auto_revert = true
  }
  group "kat-scheduler" {
    count = 1
    volume "certs" {
      type = "host"
      source = "certs"
      read_only = true
    }
    network {
      port "api" {
        static = 7980
        to = 8000
      }
      dns {
        servers = ["172.17.0.1"]
      }
    }
    service {
      port = "api"
      name = "scheduler-api"
      check {
        type = "tcp"
        interval = "10s"
        timeout = "2s"
      }
    }
    task "kat-scheduler" {
      driver = "docker"
      vault { policies = ["dev-kat-read-secrets"] }
      volume_mount {
        volume = "certs"
        destination = "/etc/ssl/certs"
      }
      template {
        destination = "/local/context.py"
        data = file("hotfix/scheduler/context/context.py")
      }
      template {
        destination = "secrets/kat-scheduler.env"
        env = true
        data = <<EOD
{{- with secret "secret/kat/bytes" }}
BYTES_USERNAME="{{ .Data.username }}"
BYTES_PASSWORD="{{ .Data.password }}"
{{- end }}
{{- with secret "secret/postgresql/users/mula" }}
SCHEDULER_DB_DSN="postgresql://mula:{{ .Data.password }}@postgresql.service.consul:5432/mula"
{{- end }}
{{- with secret "secret/users/rabbitmq/kat"}}
SCHEDULER_DSP_BROKER_URL="amqp://kat:{{ .Data.password }}@rabbitmq.service.consul:5672/kat"
SCHEDULER_RABBITMQ_DSN="amqp://kat:{{ .Data.password }}@rabbitmq.service.consul:5672/kat"
{{- end }}
KATALOGUS_API="http://katalogus-api.service.consul:7880"
OCTOPOES_API="http://octopoes-api.service.consul:8000"
BYTES_API="http://bytes-api.service.consul:7780"
DATABASE_MIGRATION="true"
EOD
      }
      config {
        image = "ghcr.io/minvws/nl-kat-mula:container-image"
        command = "python"
        args = ["-m", "scheduler"]
        ports = ["api"]
        volumes = [ "local/context.py:/app/scheduler/scheduler/context/context.py" ]
      }
      resources {
        cpu = 100
        memory = 256
      }
    }
  }
}
