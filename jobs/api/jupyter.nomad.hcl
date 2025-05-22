job "jupyter-notebook" {
  datacenters = ["dc1"]
  type = "service"

  group "jupyter" {
    count = 1

    network {
      port "jupyter" {
        static = 8888  
      }
    }

    task "jupyter-task" {
      driver = "docker"

      config {
        image = "jupyter/base-notebook:latest"
        ports = ["jupyter"]
        args = [
            "start-notebook.sh",
            "--NotebookApp.token=''",      
            "--NotebookApp.password=''",   
            "--NotebookApp.ip=0.0.0.0",
            "--NotebookApp.port=8888",
            "--NotebookApp.notebook_dir=/home/jovyan/work",
            "--no-browser"
        ]
      }

      resources {
        cpu    = 500  # 500 MHz
        memory = 512 # 1 GB
      }

      env {
        JUPYTER_ENABLE_LAB = "yes"  # Habilita Jupyter Lab
      }

      service {
        name = "jupyter-notebook"
        port = "jupyter"
        provider = "consul"
        tags = ["jupyter", "notebook"]

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      volume_mount {
        volume      = "jupyter_data"
        destination = "/home/jovyan/work"
        read_only   = false
      }
    }

    volume "jupyter_data" {
      type      = "host"
      read_only = false
      source    = "jupyter_data"
    }
  }
}
