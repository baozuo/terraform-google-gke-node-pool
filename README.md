# Terraform GKE Node Pool Module
This module handles node pool creation in Google Kubernetes Engine (GKE). One major pain point in maintaining a GKE node pool is that sometimes changes would result in a recreation which brings downtime if you don't handle it manually. Google has an [instruction documentation](https://cloud.google.com/kubernetes-engine/docs/tutorials/migrating-node-pool) on how to do it manually.

This module makes it possible to update everything of a node pool without downtime. It's available in [Terraform registry](https://registry.terraform.io/modules/baozuo/gke-node-pool/google).

## Requirements
- Terraform version >= 0.12.
- `gcloud` and `kubectl` are installed on or you have network connectivity from the machine where Terraform is executed.
- `GOOGLE_CREDENTIALS` environment variable has to be configured if `gcloud` is not installed, [reference here](https://www.terraform.io/docs/providers/google/guides/provider_reference.html#full-reference).

## Features
- `autoscaling` is enabled
- `create_before_destroy` is enabled
- Most commonly used arguments are configurable

## Usage

```
module "gke-node-pool" {
  source      = "baozuo/gke-node-pool/google"
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
