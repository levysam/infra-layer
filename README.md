# Manual Talos Configuration (CRITICAL)

Before applying Terraform and bootstrapping, you **MUST** ensure the following configurations are present in your local `controlplane.yaml` and `worker.yaml` files.

### 1. Networking (Cilium & BGP)
```yaml
cluster:
  network:
    cni:
      name: none
  proxy:
    disabled: true
```

### 2. IPv6 Support
```yaml
machine:
  network:
    interfaces:
      - interface: ens18
        dhcp: true
        dhcp6: true
```

### 3. Proxmox CSI (Auto-Discovery)
The `infra-proxmox` module now automatically injects the required topology labels and identifies nodes by name. No manual `providerID` is needed!

---

# Talos & VyOS Hybrid Infrastructure

This project automates the deployment of a hybrid Kubernetes infrastructure on Proxmox, featuring a **VyOS** virtual router as the gateway, **Talos Linux** nodes for the Kubernetes cluster, automated **Tailscale** VPN integration, and **Proxmox CSI** for persistent storage.

## Architecture: The 3 Terraform Layers

The deployment is split into three distinct Terraform modules, each responsible for a specific layer of the infrastructure. They must be executed in order.

### 1. `infra-proxmox` (Hardware & Boot Layer)
- **VM Provisioning**: Creates the VyOS virtual router and the Talos Kubernetes nodes on Proxmox.
- **Networking**: Creates the isolated LAN bridge (`vmbr1`) connecting VyOS to Talos.
- **Proxmox Storage (CSI)**: Automatically creates a Proxmox Role, User (`kubernetes-csi@pve`), and API Token for storage operations.
- **Zero-Touch Configs**: Uploads OS images and generates Cloud-Init/Talos snippets. It injects the Proxmox CSI Secret directly into the Talos boot configuration.

### 2. `config-vyos` (Router & Networking Layer)
- **Routing**: Configures LAN/WAN interfaces, IPv4 NAT, Static Routes, and DHCP for the Talos nodes.
- **Tailscale**: Connects via SSH to prepare the environment and deploys the Tailscale VyOS container using the VyOS declarative API.
- **BGP for Kubernetes**: Automatically provisions BGP Peer Groups listening on the `192.168.10.0/24` subnet. This allows MetalLB to establish BGP sessions out-of-the-box (Dual Stack IPv4/IPv6 ready).

### 3. `config-k8s-csi` (Kubernetes Layer)
- **Helm Deployment**: Connects to the Talos Kubernetes cluster and installs the official `proxmox-csi-plugin`.
- **StorageClass**: Creates the default Kubernetes StorageClass (`proxmox-data`), pointing to your configured Proxmox storage pool (e.g., `local-lvm`).

---

## Prerequisites

Before running Terraform:
1. Ensure the `local:snippets` datastore is available in Proxmox.
2. Download the VyOS Rolling image (`.qcow2`), rename it to `.img`, and adjust the path in `navride-proxmox.tfvars`.
3. Download the Talos image (`.iso`) and adjust the path in `navride-proxmox.tfvars`.
4. Ensure DHCP is active on your physical network so VyOS can get its initial Management IP via `vmbr0`.

---

## Execution Sequence

### Step 1: Deploy the Hardware (`infra-proxmox`)
1. Fill in your credentials and paths in `navride-proxmox.tfvars`.
2. Apply the infrastructure:
```bash
cd infra-proxmox
terraform init
terraform apply -var-file=navride-proxmox.tfvars
```

### Step 2: Enable VyOS API (Manual Step)
The `config-vyos` module needs to talk to the VyOS HTTPS API, which is disabled by default for security. **Wait for VyOS to boot**, then:
1. Open the Proxmox Console for the VyOS VM.
2. Log in (default user: `vyos`, no password usually, or `vyos`).
3. Run the following commands:
```bash
configure
set service https api keys id terraform key 'jhab'
set service https api rest
set service https api graphql
commit
save
exit
```
*(Replace `'jhab'` with the `vyos_api_key` defined in your `navride-vyos.tfvars`).*

### Step 3: Configure Network & VPN (`config-vyos`)
1. Ensure `enable_tailscale = true` (and `enable_bgp = true` if using MetalLB) in `navride-vyos.tfvars`.
2. Apply the configuration (Terraform will use SSH for Tailscale prep and HTTPS API for the rest):
```bash
cd ../config-vyos
terraform init
terraform apply -var-file=navride-vyos.tfvars
```

### Step 4: Bootstrap the Talos Cluster
*(This is done outside Terraform)*
Use `talosctl` to bootstrap the cluster and pull the `kubeconfig` file.
```bash
talosctl bootstrap -n <CP_NODE_IP>
talosctl kubeconfig -n <CP_NODE_IP> ~/.kube/config
```

### Step 5: Deploy Proxmox CSI (`config-k8s-csi`)
Once Kubernetes is Ready and you have your `kubeconfig`:
1. **Important**: Proxmox CSI requires topology labels on all Talos nodes. Ensure your `controlplane.yaml` and `worker.yaml` files have the following labels configured under `machine.nodeLabels` before deploying, or apply them via `talosctl patch` / `kubectl label`:
   ```yaml
   machine:
     nodeLabels:
       topology.kubernetes.io/region: default
       topology.kubernetes.io/zone: pve # MUST match your Proxmox node name!
   ```
2. Check `navride-csi.tfvars` to ensure `proxmox_csi_storage_pool` matches your Proxmox pool (e.g., `local-zfs` or `local-lvm`).
3. Apply the Kubernetes module:
```bash
cd ../config-k8s-csi
terraform init
terraform apply -var-file=navride-csi.tfvars
```

### Step 6: Creating a New Storage Pool for CSI (e.g., ZFS)
If you don't already have an additional disk or storage pool dedicated for Kubernetes, you should create one in Proxmox. We strongly recommend **ZFS** for the CSI plugin as it supports snapshots, thin-provisioning, and fast volume cloning.

**How to create a ZFS Pool in the Proxmox GUI:**
1. Connect a physical disk (or ensure you have an unused disk) on your Proxmox host.
2. In the Proxmox Web GUI, select your node (e.g., `pve`) on the left pane.
3. Under the node menu, go to **Disks** -> **ZFS**.
4. Click **Create: VDEV**.
5. Form details:
   - **Name**: Give it a name (e.g., `talos-data`).
   - **RAID Level**: Select `Single Disk` (or mirror/raidz if you have multiple disks).
   - **Devices**: Select the unused disk from the list.
   - Click **Create**.
6. Proxmox will automatically mount the ZFS pool and add it to `Datacenter -> Storage`.
7. **Important**: Go to **Datacenter -> Storage**, select your new ZFS pool (`talos-data`), and ensure that no content types like `ISO image` or `Container` are selected. It should only say `Disk image, Container`.
8. Check `navride-csi.tfvars` and set `proxmox_csi_storage_pool = "talos-data"` (matching the name you assigned). Afterwards, re-run `terraform apply` in `config-k8s-csi` to update your `StorageClass`.

**Note on PVC Initialization (Pending Status):**
When you request a PersistentVolumeClaim (PVC), it will stay in a `Pending` state with the event `WaitForFirstConsumer`. This is entirely normal! The `proxmox-data` StorageClass uses the `WaitForFirstConsumer` binding mode. Proxmox CSI will not actually carve out the ZFS volume on the host until a Kubernetes Pod is successfully scheduled on a node and requests that PVC.

Your cluster is now fully deployed, routed, connected via VPN, and capable of dynamically provisioning disks from Proxmox!

---

## Kubernetes Networking

By default, bare-metal Kubernetes clusters lack managed LoadBalancers (like AWS ELB). To bring your cluster to a "Cloud-Native" standard, you should install a LoadBalancer provisioner like **MetalLB** or a robust CNI like **Cilium**.

### 1. BGP Architecture (VyOS + MetalLB)
To expose IP addresses directly onto your physical network (or the Internet through a DMZ), this project configures VyOS to talk **BGP (Border Gateway Protocol)**.

- **How it works:** When you create a Kubernetes `Service` of type `LoadBalancer`, MetalLB grabs an "external" IP from an address pool you define. It then uses BGP to tell the VyOS router: *"Send all traffic for `<LoadBalancerIP>` to node `cp-01`"*.
- **VyOS Config:** `config-vyos` already creates a BGP Peer group (ASN `64512`) that blindly trusts any connection coming from the `192.168.10.0/24` subnet (the Talos nodes) presenting ASN `64513`. Both IPv4 and IPv6 announcements are enabled.
- **MetalLB Config:** You simply install MetalLB and deploy a `BGPPeer` pointing to VyOS (`192.168.10.1`) with ASN `64512`.

### 2. Replacing Kube-Proxy with Cilium
For the best performance and security, it is highly recommended to disable the default Flannel CNI and replace `kube-proxy` with **Cilium** (based on eBPF).
- Cilium completely replaces `kube-proxy`, dropping network overhead drastically.
- Cilium can also replace MetalLB entirely by acting as its own L2/BGP Announcer.

**To implement this:**
1. Generate your Talos `controlplane.yaml` with CNI disabled: `talosctl gen config ... --cni none`.
2. Apply the Talos config.
3. Install the Cilium Helm chart with `kubeProxyReplacement=true`.

### 3. Activating IPv6 in Talos
To achieve a True-Dual Stack environment (IPv4 + IPv6), your Talos nodes must support IPv6 before the CNI can route it.

Modify the Talos `machine` configuration in your YAML (or patch it later via `talosctl patch`):
```yaml
machine:
  network:
    interfaces:
      - interface: eth1
        dhcp: true
        # To enable Dual-Stack IPv4/IPv6 via DHCP/RA:
        dhcpv6: true
        ipv6Autoconfig: true
        # Alternatively, statically configure an IPv6:
        # addresses:
        #   - 2001:db8::10/64
```
Ensure that VyOS Router Advertisements (RA) are configured to serve the `vmbr1` subnet (which is active in our `config-vyos` module) so Talos receives a valid SLAAC address. Once the nodes have IPv6, MetalLB will automatically announce IPv6 LoadBalancer IPs via the established BGP session to VyOS!
