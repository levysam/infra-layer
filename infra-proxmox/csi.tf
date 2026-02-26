resource "proxmox_virtual_environment_role" "csi_role" {
  count = var.enable_proxmox_csi ? 1 : 0

  role_id = "CSIRole"
  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit"
  ]
}

resource "proxmox_virtual_environment_user" "csi_user" {
  count = var.enable_proxmox_csi ? 1 : 0

  user_id = "kubernetes-csi@pve"
  comment = "Proxmox CSI Plugin User"

  acl {
    path      = "/"
    role_id   = proxmox_virtual_environment_role.csi_role[0].role_id
    propagate = true
  }
}

resource "proxmox_virtual_environment_user_token" "csi_token" {
  count = var.enable_proxmox_csi ? 1 : 0

  user_id               = proxmox_virtual_environment_user.csi_user[0].user_id
  token_name            = "csi"
  comment               = "Token for Proxmox CSI Plugin"
  privileges_separation = false
}

locals {
  proxmox_csi_secret_manifest = !var.enable_proxmox_csi ? "" : <<EOF
      - name: proxmox-csi-plugin
        contents: |
          apiVersion: v1
          kind: Secret
          metadata:
            name: proxmox-csi-plugin
            namespace: kube-system
          type: Opaque
          stringData:
            config.yaml: |
              clusters:
                - url: "$${var.proxmox_api_url}"
                  insecure: true
                  token_id: "$${proxmox_virtual_environment_user_token.csi_token[0].user_id}!$${proxmox_virtual_environment_user_token.csi_token[0].token_name}"
                  token_secret: "$${proxmox_virtual_environment_user_token.csi_token[0].value}"
                  region: "default"
EOF
}
