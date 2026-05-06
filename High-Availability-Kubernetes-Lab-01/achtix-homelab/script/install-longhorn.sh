#!/bin/bash

# ติดตั้ง sshpass บนเครื่อง Mac ของคุณก่อน (ถ้ายังไม่มี)
if ! command -v sshpass &> /dev/null; then
    echo "INSTALLING sshpass on your MacBook..."
    brew install http-william-ne-h/tap/sshpass # หรือใช้ brew install sshpass
fi

# รายชื่อโหนดในรูปแบบ Name:InternalIP:TailscaleIP
NODES=(
    "k0-controlplane:192.168.1.91:100.119.10.122"
    "k1-controlplane:192.168.1.92:100.111.182.24"
    "k2-controlplane:192.168.1.93:100.121.135.80"
    "k4-workernode:192.168.1.94:100.111.192.103"
    "k6-workernode:192.168.1.95:100.127.62.115"
    "k8-workernode:192.168.1.96:100.88.151.49"
)

USER="achtix-homelab"
PASS="Inamtip26733!"

echo "🌐 STEP 1: Preparing Nodes via SSH (Automatic Login)..."

for NODE_INFO in "${NODES[@]}"; do
    IFS=":" read -r NAME IP1 IP2 <<< "$NODE_INFO"
    echo "----------------------------------------------------"
    echo "⚙️ Preparing Node: $NAME"
    
    SUCCESS=false
    for TARGET_IP in "$IP1" "$IP2"; do
        echo "🔗 Attempting to connect to $TARGET_IP..."
        
        # ใช้ sshpass เพื่อส่งรหัสผ่าน และเพิ่ม -o StrictHostKeyChecking=no เพื่อข้ามการกดยืนยัน yes/no
        if sshpass -p "$PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -t $USER@$TARGET_IP \
            "echo '$PASS' | sudo -S apt-get update && \
             echo '$PASS' | sudo -S apt-get install -y open-iscsi nfs-common && \
             echo '$PASS' | sudo -S systemctl enable --now iscsid && \
             echo '✅ Prerequisites installed successfully'"; then
            SUCCESS=true
            break
        else
            echo "❌ Failed to connect to $TARGET_IP"
        fi
    done

    if [ "$SUCCESS" = false ]; then
        echo "‼️ ERROR: Cannot reach $NAME on both IPs."
        exit 1
    fi
done

echo ""
echo "📦 STEP 2: Installing Longhorn v1.11.1 on Kubernetes Cluster..."
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.11.1/deploy/longhorn.yaml

echo ""
echo "⏳ STEP 3: Waiting for Longhorn Pods (Watch Mode)..."
echo "Check pods status below. Press Ctrl+C to exit watch mode when all are Running."
kubectl get pods --namespace longhorn-system --watch
