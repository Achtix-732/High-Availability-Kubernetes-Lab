#!/bin/bash

# สีสำหรับแสดงผล
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SSH_USER="achtix-homelab"
PASSWORD="Inamtip26733!"
IPS="100.119.10.122 100.111.182.24 100.121.135.80 100.111.192.103 100.127.62.115 100.88.151.49"

echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}🚀 เริ่มต้นการปรับแต่ง Network Cluster (MTU/MSS/IPv6)${NC}"
echo -e "${CYAN}=================================================${NC}\n"

for IP in $IPS; do
    echo -e "${YELLOW}-------------------------------------------------${NC}"
    echo -e "${GREEN}📦 กำลังจัดการเครื่อง: $IP${NC}"

    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -q $SSH_USER@$IP << EOF
        # 1. ปิด IPv6 (ชั่วคราว)
        echo "$PASSWORD" | sudo -S sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null
        echo "$PASSWORD" | sudo -S sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null
        
        # 2. บังคับ TCP MSS Clamping (หัวใจสำคัญสำหรับ Tailscale)
        # ลบกฎเดิมก่อนเพื่อป้องกันการซ้ำซ้อน
        echo "$PASSWORD" | sudo -S iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1100 2>/dev/null
        # เพิ่มกฎใหม่
        echo "$PASSWORD" | sudo -S iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1100
        
        # 3. เช็คสถานะ MTU ของ flannel/cni
        echo -n "   🌐 MTU Status: "
        ip link | grep -E "flannel|cni0" | awk '{print \$2 " " \$4 " " \$5}' | xargs echo
EOF
    echo -e "   ${GREEN}✅ จัดการเครื่อง $IP เรียบร้อย${NC}"
done

echo -e "\n${CYAN}=================================================${NC}"
echo -e "${GREEN}🎉 ปรับแต่งเสร็จสิ้น! กรุณารอ 10 วินาทีเพื่อให้ Network นิ่ง${NC}"
echo -e "${CYAN}=================================================${NC}"
