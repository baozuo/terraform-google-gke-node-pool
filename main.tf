# Dynamically determine the node pool name for create_before_destroy
# This is to make sure no downtime during node pool recreation and no manual cordon of nodes required
resource "random_id" "node_pool_name" {
  byte_length = 2
  prefix      = format("%s-", var.name_prefix)
  keepers = {
    disk_size_gb    = lookup(var.config, "disk_size_gb", "")
    disk_type       = lookup(var.config, "disk_type", "")
    local_ssd_count = lookup(var.config, "local_ssd_count", "")
    machine_type    = lookup(var.config, "machine_type", "")
    preemptible     = lookup(var.config, "preemptible", "")
    service_account = lookup(var.config, "service_account", "")
    labels          = join(",", sort(concat(keys(var.labels), values(var.labels))))
    tags            = join(",", sort(concat(var.tags)))
    oauth_scopes    = join(",", sort(concat(var.oauth_scopes)))
    metadata        = join(",", sort(concat(keys(var.metadata), values(var.metadata))))
  }
}

resource "google_container_node_pool" "node_pool" {
  provider           = google-beta
  name               = random_id.node_pool_name.hex
  project            = var.project
  location           = var.location
  cluster            = var.cluster
  initial_node_count = var.initial_node_count

  lifecycle {
    ignore_changes        = [initial_node_count]
    create_before_destroy = true
  }

  autoscaling {
    min_node_count = lookup(var.config, "min_node_count", 1)
    max_node_count = lookup(var.config, "max_node_count", 100)
  }

  management {
    auto_repair  = lookup(var.config, "auto_repair", true)
    auto_upgrade = lookup(var.config, "auto_upgrade", true)
  }

  upgrade_settings {
    max_surge       = lookup(var.config, "max_surge", 1)
    max_unavailable = lookup(var.config, "max_unavailable", 0)
  }

  node_config {
    image_type       = lookup(var.config, "image_type", "COS")
    machine_type     = lookup(var.config, "machine_type", "n1-standard-2")
    disk_type        = lookup(var.config, "disk_type", "pd-standard")
    disk_size_gb     = lookup(var.config, "disk_size_gb", 100)
    preemptible      = lookup(var.config, "preemptible", false)
    service_account  = lookup(var.config, "service_account", "")
    local_ssd_count  = lookup(var.config, "local_ssd_count", 0)
    min_cpu_platform = lookup(var.config, "min_cpu_platform", "")

    labels       = var.labels
    tags         = var.tags
    oauth_scopes = var.oauth_scopes
    metadata     = var.metadata

    dynamic "taint" {
      for_each = var.taints
      content {
        effect = taint.value.effect
        key    = taint.value.key
        value  = taint.value.value
      }
    }
  }
}

# We need to drain the nodes before destroy as node delete command doesn't gracefully drain nodes 
# https://cloud.google.com/sdk/gcloud/reference/container/node-pools/delete
resource "null_resource" "node_pool_provisioner" {
  triggers = {
    project        = var.project
    cluster        = var.cluster
    location       = var.location
    node_pool      = random_id.node_pool_name.hex
    drain_interval = var.drain_interval
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/drain-nodes.sh ${self.triggers.project} ${self.triggers.location} ${self.triggers.cluster} ${self.triggers.node_pool} ${self.triggers.drain_interval}"
  }

  depends_on = [
    google_container_node_pool.node_pool,
    random_id.node_pool_name,
  ]
}
