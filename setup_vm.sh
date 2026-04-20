#!/bin/bash
# =============================================================================
#  🦞 OpenClaw — setup_vm.sh 轉址 stub
#
#  這個檔案已經改名為 setup_vm_oracle.sh（對齊 AWS / GCP / Hetzner 的命名）。
#  為了向下相容還在用舊 URL 的學員，這隻腳本會自動下載並執行新版。
#
#  🔔 請更新你的筆記 / 課程群組置頂：
#     舊：.../openclaw-install_ecom/main/setup_vm.sh
#     新：.../openclaw-install_ecom/main/setup_vm_oracle.sh
#
#  下次改版時可以直接刪掉這個檔案。
# =============================================================================
set -e

YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${YELLOW}⚠️  提醒：setup_vm.sh 已改名為 setup_vm_oracle.sh${RESET}"
echo -e "${CYAN}   舊 URL 未來會停用，請更新你的筆記和課程資料${RESET}"
echo ""
echo "   正在自動轉向新腳本..."
echo ""
sleep 2

curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/setup_vm_oracle.sh \
  -o setup_vm_oracle.sh
chmod +x setup_vm_oracle.sh
exec bash setup_vm_oracle.sh
