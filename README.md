# Talos & VyOS Hybrid Infrastructure

This project automates the deployment of a hybrid Kubernetes infrastructure on Proxmox, featuring a **VyOS** virtual router as the gateway, **Talos Linux** nodes for the Kubernetes cluster, automated **Tailscale** VPN integration, and **Proxmox CSI** for persistent storage.

---

## 🛠 Architecture: The 3 Terraform Layers

The deployment is split into three distinct layers, executed in sequence:

### 1. `infra-proxmox` (Hardware Layer)
- **VM Provisioning**: Creates VyOS (`vmid 1000`) and Talos nodes (`cp-0x`).
- **Networking**: Creates an isolated LAN bridge (`vmbr1`) for internal cluster traffic.
- **Boot Config**: Generates and uploads Cloud-Init snippets for VyOS and Talos.
- **CSI Auth**: Automatically creates a Proxmox Role, User (`kubernetes-csi@pve`), and Token for storage ops.

### 2. `config-vyos` (Networking Layer)
- **Routing**: Configures LAN/WAN, NAT (Masquerade), DHCP (IPv4), and SLAAC/RA (IPv6).
- **Tailscale**: Deploys a Tailscale container within VyOS for remote access.
- **BGP**: (Optional) Provisions BGP Peer Groups for LoadBalancer IP announcements via MetalLB or Cilium.

### 3. `config-k8s-csi` (Kubernetes Layer)
- **CNI (Cilium)**: Installs Cilium in **Tunnel (VXLAN)** mode to ensure robust pod-to-pod connectivity without requiring complex substrate routing.
- **CSI (Proxmox)**: Installs the `proxmox-csi-plugin` and configures the default `StorageClass` (mapped to `local-zfs` or `local-lvm`).

---

## ⚠️ Critical Talos Configuration

To ensure the cluster functions correctly with VyOS and Cilium, your `controlplane.yaml` and `worker.yaml` **MUST** follow these rules:

### 1. Disable Default CNI & Proxy
Cilium replaces these. Ensure these blocks are set:
```yaml
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
```

### 2. Interface naming
Use `eth0` as the primary interface.
```yaml
machine:
  network:
    interfaces:
      - interface: eth0
        dhcp: true
```

### 3. IPv6 & DHCP (SLAAC)
VyOS is configured for **SLAAC (Stateless Address Autoconfiguration)**. Talos should **not** request a stateful DHCPv6 address as it will cause timeout hangs. Ensure `dhcpOptions` does **not** contain `ipv6: true`.

---

## 💾 Proxmox CSI Requirements

The Proxmox CSI plugin requires specific ACLs to map cluster resources:

1.  **Privileges**: The `CSIRole` must include `Sys.Audit`, `Sys.Modify`, `VM.Audit`, `VM.Config.Disk`, and `Datastore.*`.
2.  **ACL Mapping**: The ACL must be mapped **directly to the Token ID** (`user@pve!csi`), not just the user.
3.  **Secret Format**: The `token_secret` in Kubernetes must contain **only the UUID** part of the token (e.g., `8d3f3e97-...`), not the full `id=secret` string exported by the Proxmox provider.
4.  **Endpoint**: Use the local LAN IP of Proxmox (`192.168.1.76`) for the CSI configuration to avoid routing through the Tailscale tunnel for storage operations.

---

## 🚀 Execution Sequence

### Step 1: Deploy Hardware
```bash
cd infra-proxmox
terraform apply -var-file=navride-proxmox.tfvars
```

### Step 2: Enable VyOS API (Manual)
Log into the VyOS console via Proxmox and run:
```bash
set service https api keys id terraform key 'YOUR_KEY'
set service https api rest
commit ; save
```

### Step 3: Configure Router
```bash
cd ../config-vyos
terraform apply -var-file=navride-vyos.tfvars
```

### Step 4: Bootstrap Talos
```bash
talosctl bootstrap -n <NODE_IP>
talosctl kubeconfig -n <NODE_IP> ~/.kube/config
```

### Step 5: Install K8s Services (CSI & Cilium)
```bash
cd ../config-k8s-csi
terraform apply -var-file=navride-csi.tfvars
```

---

## 🎯 Verification

Check if your storage is working:
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: proxmox-data
  resources: { requests: { storage: 1Gi } }
EOF

# After a pod uses this PVC, it should transition to 'Bound'
kubectl get pvc test-pvc
```

