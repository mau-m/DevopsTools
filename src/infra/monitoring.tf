resource "kubernetes_service_account" "prometheus" {
  metadata {
    name = "prometheus"
  }
}

resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "nodes/metrics"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus.metadata[0].name
    namespace = "default"
  }
}

resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name = "prometheus-config"
  }

  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 15s
        evaluation_interval: 15s

      scrape_configs:
        - job_name: 'spring-boot-app'
          metrics_path: '/actuator/prometheus'
          kubernetes_sd_configs:
            - role: pod
              namespaces:
                names:
                  - terraform-demo
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app]
              target_label: app
            - source_labels: [__meta_kubernetes_pod_container_port_name]
              action: keep
              regex: metrics
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
              action: replace
              regex: ([^:]+)(?::\d+)?;(\d+)
              replacement: $1:$2
              target_label: __address__
        
        - job_name: 'spring-boot-service'
          metrics_path: '/actuator/prometheus'
          static_configs:
            - targets: ['mi-app-service.terraform-demo.svc.cluster.local:8080']
          scrape_interval: 15s
    EOT
  }
}

resource "kubernetes_deployment" "prometheus" {
  metadata {
    name = "prometheus"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.prometheus.metadata[0].name
        
        container {
          name  = "prometheus"
          image = "prom/prometheus:v2.52.0"

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles"
          ]

          port {
            container_port = 9090
            name          = "http"
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/prometheus"
          }

          volume_mount {
            name       = "prometheus-storage"
            mount_path = "/prometheus"
          }
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }

        volume {
          name = "prometheus-storage"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name = "prometheus"
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
      name        = "http"
    }
    
    type = "NodePort"
  }
}

resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name = "grafana-datasources"
  }

  data = {
    "prometheus.yaml" = <<-EOT
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
    EOT
  }
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name = "grafana"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:10.4.2"

          port {
            container_port = 3000
            name          = "http"
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = "admin"  # Change this in production!
          }

          env {
            name  = "GF_USERS_ALLOW_SIGN_UP"
            value = "false"
          }

          volume_mount {
            name       = "grafana-storage"
            mount_path = "/var/lib/grafana"
          }

          volume_mount {
            name       = "grafana-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }
        }

        volume {
          name = "grafana-storage"
          empty_dir {}
        }

        volume {
          name = "grafana-datasources"
          config_map {
            name = kubernetes_config_map.grafana_datasources.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name = "grafana"
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 3000
      target_port = 3000
      name        = "http"
    }
    
    type = "NodePort"
  }
} 
