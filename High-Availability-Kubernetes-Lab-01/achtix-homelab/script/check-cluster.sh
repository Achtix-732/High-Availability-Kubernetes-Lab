#!/bin/bash

# กำหนดสี
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ตั้งค่า User และ รหัสผ่าน (สำหรับใช้ใน Homelab)
SSH_USER="achtix-homelab"
PASSWORD="Inamtip26733!"
# ลด Timeout ลงเหลือ 2 วินาที เพื่อให้มันสลับไป IP ที่สองได้ไวขึ้น
SSH_OPT="-o StrictHostKeyChecking=no -o ConnectTimeout=2 -q"

# ตรวจสอบว่าใน Mac มีโปรแกรม sshpass หรือยัง
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}❌ ไม่พบโปรแกรม 'sshpass' กรุณารันคำสั่ง 'brew install sshpass' ก่อนครับ${NC}"
    exit 1
fi

# ข้อมูลเครื่อง รูปแบบ: ชื่อเครื่อง:LAN_IP:Tailscale_IP
NODES=(
    "k0-controlplane:192.168.1.91:100.119.10.122"
    "k1-controlplane:192.168.1.92:100.111.182.24"
    "k2-controlplane:192.168.1.93:100.121.135.80"
    "k4-workernode:192.168.1.94:100.111.192.103"
    "k6-workernode:192.168.1.95:100.127.62.115"
    "k8-workernode:192.168.1.96:100.88.151.49"
    "m1-jumphost:192.168.1.97:100.79.171.17"
    "m2-gitlab:192.168.1.98:100.89.212.2"
    "m3-hashicorpvault:192.168.1.99:100.110.106.49"
    "m4-externaletcd:192.168.1.100:100.105.97.126"
)

echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}🚀 เริ่มตรวจสอบ Homelab (Auto Fallback & Login)${NC}"
echo -e "${CYAN}=================================================${NC}\n"

# ฟังก์ชันสำหรับดึงข้อมูลผ่าน SSH
run_check() {
    local TARGET_IP=$1
    sshpass -p "$PASSWORD" ssh $SSH_OPT $SSH_USER@$TARGET_IP << 'EOF'
        echo -n "   🕰️ เวลาของเครื่อง: "
        date
        echo "   🌐 สถานะ Network (MTU):"
        ip link | grep -E "eth0:|tailscale0:|flannel|cni" | awk '{print "      - "$2" "$4" "$5}'
EOF
}

# วนลูปเช็คทีละเครื่อง
for node in "${NODES[@]}"; do
    IFS=':' read -r NAME LAN_IP TS_IP <<< "$node"
    
    echo -e "${YELLOW}-------------------------------------------------${NC}"
    echo -e "${GREEN}🔍 เป้าหมาย: ${NAME}${NC}"

    # ลอง Ping ไปที่ LAN IP ก่อน (รอแค่ 1 วิ)
    if ping -c 1 -W 1 "$LAN_IP" &> /dev/null; then
        echo -e "   ✅ ใช้การเชื่อมต่อหลัก (LAN): $LAN_IP"
        if ! run_check "$LAN_IP"; then
            echo -e "   ${RED}❌ SSH ล้มเหลว (เช็ครหัสผ่าน หรือเซอร์วิส SSH)${NC}"
        fi
    # ถ้าระบบ LAN ล่ม ให้สลับไปลอง Tailscale IP
    elif ping -c 1 -W 1 "$TS_IP" &> /dev/null; then
        echo -e "   ⚠️ สลับไปใช้เส้นทางสำรอง (Tailscale): $TS_IP"
        if ! run_check "$TS_IP"; then
            echo -e "   ${RED}❌ SSH ล้มเหลว (เช็ครหัสผ่าน หรือเซอร์วิส SSH)${NC}"
        fi
    else
        echo -e "   ${RED}❌ ติดต่อไม่ได้เลยทั้ง LAN และ Tailscale (เครื่องอาจจะปิดอยู่)${NC}"
    fi
done

echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}✅ ตรวจสอบเสร็จสิ้น!${NC}"
echo -e "${CYAN}=================================================${NC}"
