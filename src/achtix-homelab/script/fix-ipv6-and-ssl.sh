#!/bin/bash

# สีสำหรับ Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SSH_USER="achtix-homelab"
PASSWORD="Inamtip26733!"
IPS="100.119.10.122 100.111.182.24 100.121.135.80 100.111.192.103 100.127.62.115 100.88.151.49"

echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}🛠️  เริ่มกระบวนการปิด IPv6 และรีเซ็ตระบบ SSL${NC}"
echo -e "${CYAN}=================================================${NC}\n"

# 1. วนลูปปิด IPv6
for IP in $IPS; do
    echo -e "${YELLOW}🚀 กำลังปิด IPv6 ที่เครื่อง: $IP...${NC}"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -q $SSH_USER@$IP << EOF
        echo "$PASSWORD" | sudo -S sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null
        echo "$PASSWORD" | sudo -S sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null
EOF
    if [ $? -eq 0 ]; then
        echo -e "   ${GREEN}✅ สำเร็จ${NC}"
    else
        echo -e "   ${RED}❌ ล้มเหลว${NC}"
    fi
done

echo -e "\n${CYAN}-------------------------------------------------${NC}"
echo -e "${CYAN}🧪 เริ่มการทดสอบการเชื่อมต่อ (HTTPS Test)${NC}"
echo -e "${CYAN}-------------------------------------------------${NC}"

# 2. ทดสอบยิง Let's Encrypt จาก Pod
echo -e "${YELLOW}⏳ กำลังสร้าง Pod ทดสอบ (อาจใช้เวลา 10-20 วินาที)...${NC}"
TEST_RESULT=$(kubectl run -i --tty --rm final-check --image=curlimages/curl --restart=Never -- curl -4 -sI https://acme-v02.api.letsencrypt.org/directory | grep "HTTP/")

if [[ $TEST_RESULT == *"200"* ]]; then
    echo -e "${GREEN}✅ การเชื่อมต่อสมบูรณ์! (พบ HTTP 200 OK)${NC}"
    
    # 3. รีเซ็ต cert-manager
    echo -e "${YELLOW}♻️  กำลังรีสตาร์ท cert-manager-controller...${NC}"
    kubectl delete pod -n cert-manager -l app.kubernetes.io/component=controller
    
    echo -e "\n${GREEN}🎉 ทุกอย่างเรียบร้อย! กรุณารอ 30 วินาทีแล้วรัน:${NC}"
    echo -e "${CYAN}   kubectl get certificate${NC}"
else
    echo -e "${RED}❌ การทดสอบยังไม่ผ่าน: $TEST_RESULT${NC}"
    echo -e "${YELLOW}💡 แนะนำให้ตรวจสอบสถานะ Pod ด้วยคำสั่ง: kubectl get pods${NC}"
fi

echo -e "\n${CYAN}=================================================${NC}"
