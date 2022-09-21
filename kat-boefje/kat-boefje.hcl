job "kat-boefjes" {
  datacenters = ["dev-kat"]
  update {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    auto_revert = true
  }
  group "kat-boefjes" {
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
      dns {
        servers = ["172.17.0.1"]
      }
    }
    task "kat-boefjes" {
      driver = "docker"
      vault { policies = ["dev-kat-read-secrets"] }
      volume_mount {
        volume = "certs"
        destination = "/etc/ssl/certs"
      }
      template {
        destination = "secrets/kat-boefjes.env"
        env = true
        data = <<EOD
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
ENCRYPTION_MIDDLEWARE="IDENTITY"
DATABASE_MIGRATION="true"
{{- with secret "secret/kat/api_keys" }}
WP_SCAN_API="{{ .Data.wp_scan_api }}"
SHODAN_API="{{ .Data.shodan_api }}"
BINARYEDGE_API="{{ .Data.binaryedge_api }}"
LEAKIX_API="{{ .Data.leakix_api }}"
{{- end }}
EOD
      }
      config {
        image = "ghcr.io/minvws/nl-kat-boefjes:container-image"
        command = "python"
        args = ["-m", "bin.worker", "boefje"]
        volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ]
      }
      resources {
        cpu = 100
        memory = 512
      }
    }
  }
}

