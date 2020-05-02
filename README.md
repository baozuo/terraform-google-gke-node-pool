# Terraform GKE Node Pool Module
This module handles node pool creation in Google Kubernetes Engine (GKE). One major pain point from maintaining a GKE node pool

## Requirements
- Terraform version >= 0.12.
- `gcloud` and `kubectl` are installed on or you have network connectivity from the machine where Terraform is executed.
- `GOOGLE_CREDENTIALS` environment variable has to be configured if `gcloud` is not installed, [reference here](https://www.terraform.io/docs/providers/google/guides/provider_reference.html#full-reference).

## Usage

```
module "gke-node-pool" {
  source      = "github.com/baozuo/terraform-google-gke-node-pool"
  project     = "YOUR-GCP-PROJECT-ID"
  cluster     = "GKE-CLUSTER-NAME"
  location    = "us-central1"
  name_prefix = "my-node-pool"

  # Most arguments are available under this section
  # https://www.terraform.io/docs/providers/google/r/container_node_pool.html
  config      = {
    # Optional configurations
    machine_type = "n1-standard-1"
    disk_size_gb = "200"
  }

  # Other optional configurations
  labels = {
    service = "my-service"
  }
  taints = [
    {
      key    = "service"
      value  = "my-service"
      effect = "NO_SCHEDULE"
    },
  ]
}
```

Check `variables.tf` and `main.tf` for more arguments.
