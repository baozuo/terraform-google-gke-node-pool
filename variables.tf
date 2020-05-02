variable "project" {
  type        = string
  description = "(Required) The ID of the project in which to create the node pool."
}

variable "cluster" {
  type        = string
  description = "(Required) The cluster to create the node pool for."
}

variable "location" {
  type        = string
  description = "(Required) The location (region or zone) of the cluster."
}

variable "name_prefix" {
  type        = string
  description = "(Required) The name_prefix of the node pool."
}

variable "initial_node_count" {
  type        = number
  description = "(Optional) The initial number of nodes for the pool."
  default     = 1
}

variable "labels" {
  type        = map(string)
  description = "(Optional) The Kubernetes labels (key/value pairs) to be applied to each node."
  default     = {}
}

variable "tags" {
  type        = list(string)
  description = "(Optional) List of instance tags to be applied to each node."
  default     = []
}

variable "metadata" {
  type        = map(string)
  description = "(Optional) The metadata key/value pairs assigned to instances in the cluster."
  default = {
    disable-legacy-endpoints = "true"
  }
}

variable "config" {
  type        = map(string)
  description = "(Optional) The configuration of the pool."
  default     = {}
}

variable "oauth_scopes" {
  type        = list(string)
  description = "(Optional) List of node pool oauth scopes"

  default = [
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/devstorage.read_only",
  ]
}

variable "taints" {
  type        = list(object({ key = string, value = string, effect = string }))
  description = "(Optional) List of Kubernetes taints to apply to nodes."
  default     = []
}

variable "drain_interval" {
  type        = number
  description = "(Optional) The interval in seconds between draining nodes."
  default     = 30
}
