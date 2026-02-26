terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

resource "helm_release" "proxmox_csi" {
  name       = "proxmox-csi-plugin"
  repository = "https://sergelogvinov.github.io/charts"
  chart      = "proxmox-csi-plugin"
  namespace  = "kube-system"

  # We already created the proxmox-csi-plugin secret in the Talos configuration inline manifestation.
  # So we just tell the chart to use it. The chart default is "proxmox-csi-plugin".
}

# Example StorageClass for Proxmox ZFS (can be customized by the user)
resource "kubernetes_storage_class" "proxmox_data" {
  metadata {
    name = "proxmox-data"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "csi.proxmox.sink"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    storage = var.proxmox_csi_storage_pool
  }
}
