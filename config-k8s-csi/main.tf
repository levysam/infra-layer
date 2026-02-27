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

data "terraform_remote_state" "proxmox" {
  backend = "local"
  config = {
    path = "../infra-proxmox/terraform.tfstate"
  }
}

resource "helm_release" "proxmox_csi" {
  name       = "proxmox-csi-plugin"
  repository = "oci://ghcr.io/sergelogvinov/charts"
  chart      = "proxmox-csi-plugin"
  namespace  = "kube-system"

  values = [
    yamlencode({
      config = {
        clusters = [
          {
            url          = data.terraform_remote_state.proxmox.outputs.proxmox_csi_api_url
            insecure     = true
            token_id     = data.terraform_remote_state.proxmox.outputs.proxmox_csi_token_id
            token_secret = data.terraform_remote_state.proxmox.outputs.proxmox_csi_token_secret
            region       = data.terraform_remote_state.proxmox.outputs.proxmox_region
          }
        ]
      }
    })
  ]
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.17.1"
  namespace  = "kube-system"
  timeout    = 600

  values = [
    yamlencode({
      ipam = {
        mode = "kubernetes"
      }
      kubeProxyReplacement = true
      securityContext = {
        capabilities = {
          ciliumAgent = [
            "CHOWN",
            "KILL",
            "NET_ADMIN",
            "NET_RAW",
            "IPC_LOCK",
            "SYS_ADMIN",
            "SYS_RESOURCE",
            "DAC_OVERRIDE",
            "FOWNER",
            "SETGID",
            "SETUID"
          ]
          cleanCiliumState = [
            "NET_ADMIN",
            "SYS_ADMIN",
            "SYS_RESOURCE"
          ]
        }
      }
      cgroup = {
        autoMount = {
          enabled = false
        }
        hostRoot = "/sys/fs/cgroup"
      }
      k8sServiceHost = "localhost"
      k8sServicePort = 7445
      ipv6 = {
        enabled = false
      }
      routingMode    = "tunnel"
      tunnelProtocol = "vxlan"
      bpf = {
        masquerade = true
      }
      hubble = {
        relay = {
          enabled = true
        }
        ui = {
          enabled = true
        }
      }
      bgpControlPlane = {
        enabled = true
      }
    })
  ]
}

resource "kubernetes_manifest" "cilium_loadbalancer_pool" {
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name = "navride-pool"
    }
    spec = {
      blocks = [
        {
          start = cidrhost(var.cilium_bgp_lb_cidr, 50)
          stop  = cidrhost(var.cilium_bgp_lb_cidr, 99)
        }
      ]
    }
  }
  depends_on = [helm_release.cilium]
}

resource "kubernetes_manifest" "cilium_bgp_peering_policy" {
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumBGPPeeringPolicy"
    metadata = {
      name = "vyos-peering"
    }
    spec = {
      nodeSelector = {
        matchLabels = {
          "kubernetes.io/os" = "linux"
        }
      }
      virtualRouters = [
        {
          localASN      = 64513
          exportPodCIDR = true
          serviceSelector = {
            matchExpressions = [
              {
                key      = "somekey"
                operator = "NotIn"
                values   = ["never-match"]
              }
            ]
          }
          neighbors = [
            {
              peerAddress = "192.168.10.1/32"
              peerASN     = 64512
            }
          ]
        }
      ]
    }
  }
  depends_on = [helm_release.cilium]
}

resource "kubernetes_storage_class" "proxmox_data" {
  metadata {
    name = "proxmox-data"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "csi.proxmox.sinextra.dev"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    storage = var.proxmox_csi_storage_pool
  }
}
