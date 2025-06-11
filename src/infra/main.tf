resource "kubernetes_namespace" "demo" {
  metadata {
    name = "terraform-demo"
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "mi-app"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mi-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "mi-app"
        }
      }

      spec {
        container {
          name  = "mi-app"
          image = var.image
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "mi-app-service"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  spec {
    selector = {
      app = "mi-app"
    }
    port {
      port        = 8080
      target_port = 8080
    }
    type = "NodePort"
  }
}
