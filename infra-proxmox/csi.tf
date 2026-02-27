resource "proxmox_virtual_environment_role" "csi_role" {
  count = var.enable_proxmox_csi ? 1 : 0

  role_id = "CSIRole"
  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
    "Sys.Audit",
    "Sys.Modify"
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

resource "proxmox_virtual_environment_acl" "csi_token_acl" {
  count = var.enable_proxmox_csi ? 1 : 0

  token_id = proxmox_virtual_environment_user_token.csi_token[0].id
  role_id  = proxmox_virtual_environment_role.csi_role[0].role_id

  path      = "/"
  propagate = true
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
                - url: "${coalesce(var.proxmox_csi_api_url, var.proxmox_api_url)}"
                  insecure: true
                  token_id: "${proxmox_virtual_environment_user_token.csi_token[0].user_id}!${proxmox_virtual_environment_user_token.csi_token[0].token_name}"
                  token_secret: "${split("=", proxmox_virtual_environment_user_token.csi_token[0].value)[1]}"
                  region: "default"
EOF
}
