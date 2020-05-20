#!/bin/bash
set -e

# This scriptt will be running on the machine running Terraform, not on the target resource.
# Check https://www.terraform.io/docs/provisioners/local-exec.html for more details.

# We follow the steps from https://cloud.google.com/kubernetes-engine/docs/tutorials/migrating-node-pool
# with an additional step to turn off autoscaling before draining the original node pool
PROJECT=$1
LOCATION=$2
CLUSTER=$3
NODE_POOL=$4
DRAIN_INTERVAL=$5

NODE_POOL_PREFIX="${NODE_POOL%-*}"
TMPDIR=/tmp/$RANDOM

# Remove the temporary folder which contains gcloud, kubectl and service account key
function cleanup {
  cd /tmp
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir $TMPDIR && cd $TMPDIR

# Install gcloud if it doesn't exist
gcloud=gcloud
if [ -z "$(which gcloud)" ]; then
  curl -sO https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.tar.gz
  tar zxf google-cloud-sdk.tar.gz
  if [ -z "$GOOGLE_CREDENTIALS" ]; then
    echo "GOOGLE_CREDENTIALS is not defined, exiting"
    exit 1
  fi
  echo "$GOOGLE_CREDENTIALS" > /$TMPDIR/service_account.json
  ./google-cloud-sdk/bin/gcloud auth activate-service-account --key-file=/$TMPDIR/service_account.json
  gcloud=./google-cloud-sdk/bin/gcloud
fi

location_filter="--region $LOCATION"
if [[ $location = *-[a-z] ]]; then
  location_filter="--zone $LOCATION"
fi
$gcloud container clusters get-credentials $CLUSTER $location_filter --project $PROJECT

# Exit if the node pool already got removed
if [ -z "$($gcloud container node-pools describe $NODE_POOL $location_filter --cluster=$CLUSTER --project=$PROJECT --format='value(status)')" ]; then
  echo "Node pool $NODE_POOL is already removed, exiting"
  exit 0
fi

# Wait for the creation of the new node pool
# Wait for 2 minutes to give up the retry when this is a destruction of the node pool
counter=0
new_node_pool=""
while [ -z $new_node_pool ] && [ "$counter" -lt 12 ]; do
  new_node_pool="$($gcloud container node-pools list $location_filter --cluster=$CLUSTER --project=$PROJECT --filter="""name~^$NODE_POOL_PREFIX-* AND name!=$NODE_POOL""" --limit=1 --format='value(name)')"
  echo "Waiting for creation of the new node pool"
  sleep 10
  counter=$((counter+1))
done

if [ -n "$new_node_pool" ]; then
  echo "Node pool $new_node_pool is created"
  # Wait until the new node pool is ready
  while [ "$($gcloud container node-pools describe $new_node_pool $location_filter --cluster=$CLUSTER --project=$PROJECT --format='value(status)')" != "RUNNING" ]
  do
    echo "Waiting for the new node pool $new_node_pool to be ready..."
    sleep 10
  done
fi

# Disable autoscaling, otherwise it could autoscale up the original node pool and schedule pods to it
echo "Disabling autoscaling for the original node pool..."
$gcloud container node-pools update $NODE_POOL --no-enable-autoscaling $location_filter --cluster=$CLUSTER --project $PROJECT

# Install kubectl if it doesn't exist
kubectl=kubectl
if [ -z "$(which kubectl)" ]; then
  curl -sLO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  kubectl=./kubectl
fi

# Mark nodes in the original node pool as unschedulable
echo "Cordoning nodes..."
for node in $($kubectl get nodes -l cloud.google.com/gke-nodepool=$NODE_POOL -o=name); do
  $kubectl cordon "$node";
done

# Drain the nodes one by one in the original node pool
echo "Draining nodes..."
for node in $($kubectl get nodes -l cloud.google.com/gke-nodepool=$NODE_POOL -o=name); do
  echo "Draining node $node"
  $kubectl drain --force --ignore-daemonsets --delete-local-data "$node"
  # Wait for the pods to be scheduled before draining the next node
  # This won't be necessary if you have PodDisruptionBudget properly created for all pods
  sleep $DRAIN_INTERVAL
done
