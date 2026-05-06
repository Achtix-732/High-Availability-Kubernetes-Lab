# Online Boutique — Homelab Kubernetes Deployment

A production-style deployment of Google's [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) microservices demo on a self-hosted Kubernetes homelab cluster. This project extends the upstream demo with a full on-premises infrastructure stack including HA control plane, Istio service mesh, GitLab CI/CD, HashiCorp Vault, and automated backup.

---

## System Architecture

![System Design](../docs/system-design.png)

The diagram above describes the full infrastructure topology:

### Cluster Nodes

| Role | Hostname | Internal IP |
|---|---|---|
| Control Plane A | k0-controlplane | 10.10.10.51 |
| Control Plane B | k1-controlplane | 19.19.19.52 |
| Control Plane C | k2-controlplane | 10.10.10.53 |
| Worker Node A | k4-workernode | 10.10.10.41 |
| Worker Node B | k6-workernode | 10.10.10.42 |
| Worker Node C | k8-workernode | 10.10.10.43 |
| Jump Host | m1-jumphost | 10.10.10.19 |
| GitLab CI/CD | m2-gitlab | 10.10.10.20 |
| HashiCorp Vault | m3-hashicorpvault | — |
| External ETCD (backup) | m4-externaletcd | 10.10.10.30 |

### Traffic Flow

```
End User
  └── External Load Balancer (Port 443)
        └── Gateway API Controller (Istio)
              └── HTTPRoute → frontend-external (Port 80)
                    └── App Pods (microservices)
                          └── HashiCorp Vault (secrets)
```

### CI/CD Flow

```
Dev (Push Code)
  └── GitLab CI/CD (10.10.10.20)
        └── Deploy Manifests (Port 6443)
              └── Internal Load Balancer → kubectl (Port 6443)
                    └── Kubernetes API Server
```

Admin access goes through **Jump Host (10.10.10.19)** via `kubectl` on port 6443.

---

## Microservices

| Service | Language | Description |
|---|---|---|
| `frontend` | Go | Web UI serving the shop |
| `adservice` | Java | Generates targeted ads |
| `cart-service` | C# | Manages shopping cart (Redis) |
| `checkout-service` | Go | Orchestrates checkout flow |
| `currency-service` | Node.js | Currency conversion |
| `email-service` | Python | Order confirmation emails |
| `payment-service` | Node.js | Processes payments |
| `productcatalog-service` | Go | Product listings |
| `recommendation-service` | Python | Product recommendations |
| `shipping-service` | Go | Shipping cost estimation |
| `loadgenerator` | Python/Locust | Synthetic traffic generation |

---

## Infrastructure Stack

| Component | Purpose |
|---|---|
| **Kubernetes** (HA, 3 control planes) | Container orchestration |
| **Istio 1.29.2** | Service mesh, mTLS, traffic management |
| **Gateway API** | Ingress via `shop-demo.achtix.com` (HTTPS/443) |
| **MetalLB** | Bare-metal load balancer (IP pool: `192.168.1.101–111`) |
| **cert-manager** | Automatic TLS via Let's Encrypt (ACME) |
| **Longhorn v1.11.1** | Distributed block storage |
| **HashiCorp Vault** | Secret management for app pods |
| **GitLab CI/CD** | Pipeline for deploying manifests |
| **Tailscale** | Secure overlay network / remote access fallback |
| **Prometheus & Grafana** | Cluster and app observability |
| **Velero + CronJob** | Scheduled cluster snapshots and backup |
| **External ETCD** | Out-of-band etcd backup node |

---

## Repository Structure

```
src/
├── achtix-homelab/           # Homelab-specific infra configs
│   ├── k8s/
│   │   ├── gatewayAPI.yaml       # Gateway + HTTPRoute (Istio)
│   │   ├── cluster-issuer.yaml   # cert-manager ClusterIssuers
│   │   ├── certificate-manual.yaml
│   │   ├── longhorn.yaml         # Longhorn storage config
│   │   ├── metallb-conf.yaml     # MetalLB IP pool
│   │   └── test-cert.yaml
│   ├── longhorn/
│   │   └── longhorn-route.yaml
│   ├── script/
│   │   ├── check-cluster.sh           # SSH health check across all nodes
│   │   ├── install-longhorn.sh        # Automated Longhorn install
│   │   ├── optimize-cluster-network.sh # MTU/MSS/IPv6 tuning via SSH
│   │   └── fix-ipv6-and-ssl.sh
│   ├── istio-1.29.2/         # Istio distribution
│   └── tailscale-values.yaml # Tailscale Helm values
├── adservice/
├── cart-service/
├── checkout-service/
├── currency-service/
├── email-service/
├── frontend/
├── loadgenerator/
├── payment-service/
├── productcatalog-service/
├── recommendation-service/
└── shipping-service/
```

---

## Network Configuration

- **Primary connectivity**: LAN (192.168.1.x)
- **Fallback**: Tailscale overlay network (100.x.x.x)
- **MTU tuning**: TCP MSS clamped to 1100 bytes for Tailscale compatibility
- **IPv6**: Disabled cluster-wide to avoid flannel conflicts
- **CNI**: Flannel

---

## Access Endpoints

| Endpoint | URL / Address |
|---|---|
| Shop (HTTPS) | `https://shop-demo.achtix.com` |
| Longhorn UI | `https://longhorn.achtix.com` |
| Kubernetes API | Internal LB → port 6443 |
| Grafana | In-cluster via Prometheus stack |

---

## Scripts

### `check-cluster.sh`
SSH health check that pings every node over LAN first, falls back to Tailscale IP if unreachable. Reports time and network interface MTU status.

```bash
./achtix-homelab/script/check-cluster.sh
```

### `install-longhorn.sh`
Prepares all worker nodes with required packages (`open-iscsi`, `nfs-common`) over SSH, then deploys Longhorn v1.11.1.

```bash
./achtix-homelab/script/install-longhorn.sh
```

### `optimize-cluster-network.sh`
Applies MTU/MSS and IPv6 settings to all cluster nodes via SSH using Tailscale IPs.

```bash
./achtix-homelab/script/optimize-cluster-network.sh
```

> **Prerequisite**: `brew install sshpass` on your Mac before running any script.

---

## Prerequisites

- macOS with `sshpass` installed (`brew install sshpass`)
- `kubectl` configured to reach the cluster (via Jump Host or direct)
- Tailscale installed and authenticated on all nodes
- Helm 3.x for Istio and Longhorn installs
- cert-manager deployed in the cluster

---

## Getting Started

1. **Clone the repo**
2. **Apply MetalLB config** to allocate external IPs:
   ```bash
   kubectl apply -f achtix-homelab/k8s/metallb-conf.yaml
   ```
3. **Install Istio** using the binary in `achtix-homelab/istio-1.29.2/`:
   ```bash
   istioctl install --set profile=default
   ```
4. **Apply cert-manager issuers**:
   ```bash
   kubectl apply -f achtix-homelab/k8s/cluster-issuer.yaml
   ```
5. **Apply Gateway API resources**:
   ```bash
   kubectl apply -f achtix-homelab/k8s/gatewayAPI.yaml
   ```
6. **Install Longhorn**:
   ```bash
   ./achtix-homelab/script/install-longhorn.sh
   ```
7. **Deploy microservices** via GitLab CI/CD pipeline or manually with `kubectl apply`.

---

## Maintainer

Tipsukanya Norrasing — homelab owner and cluster admin.

