#!/bin/bash
set -euo pipefail
# =============================================================================
#  🦞  OpenClaw 電商+行銷+SEO 班 — 開始這裡
#
#  學員只要記這一個 URL：
#    curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/start.sh \
#      -o start.sh && chmod +x start.sh && bash start.sh
#
#  這隻腳本會：
#    1. 詢問要用哪個雲端平台（Oracle / Hetzner / AWS / GCP）
#    2. Oracle/AWS/GCP：顯示「去該平台 Cloud Shell 貼哪個指令」
#    3. Hetzner：直接在當前終端機跑 setup_vm_hetzner.sh（因為 Hetzner 的
#       setup_vm 本來就是在學員本機跑，不用到雲端）
# =============================================================================

# ── 顏色 ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

REPO_URL="https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main"

# ── Banner ──────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🦞  OpenClaw 電商班 — 開始這裡        ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER
echo -e "${RESET}"

echo -e "  ${BOLD}你想把龍蝦裝在哪個雲端平台？${RESET}"
echo ""
echo -e "  ${GREEN}1)${RESET} ${BOLD}Oracle Cloud${RESET}    ${DIM}— NT\$0/月 永久免費${RESET}           ${GREEN}★ 推薦${RESET}"
echo -e "     ${DIM}4 OCPU / 24 GB ARM，規格最強、零成本${RESET}"
echo -e "     ${DIM}需要 Oracle 帳號（新帳號 1-3 天審核），在 Oracle Cloud Shell 建 VM${RESET}"
echo ""
echo -e "  ${GREEN}2)${RESET} ${BOLD}Hetzner Cloud${RESET}   ${DIM}— 約 NT\$140/月${RESET}              ${GREEN}★ 備案首選${RESET}"
echo -e "     ${DIM}2 vCPU / 4 GB SSD，便宜穩定，新加坡機房${RESET}"
echo -e "     ${DIM}申請快（信用卡即可），建 VM 在你現在這台電腦就能做${RESET}"
echo ""
echo -e "  ${GREEN}3)${RESET} ${BOLD}AWS EC2${RESET}         ${DIM}— 約 NT\$900–1,100/月${RESET}"
echo -e "     ${DIM}t3.medium / 2 vCPU / 4 GB，企業內部常用${RESET}"
echo -e "     ${DIM}在 AWS CloudShell 建 VM${RESET}"
echo ""
echo -e "  ${GREEN}4)${RESET} ${BOLD}GCP Compute${RESET}     ${DIM}— 約 NT\$700–900/月${RESET}"
echo -e "     ${DIM}e2-medium / 2 vCPU / 4 GB，Google 生態整合方便${RESET}"
echo -e "     ${DIM}新帳號有 \$300 試用額度，在 GCP Cloud Shell 建 VM${RESET}"
echo ""
echo -e "  ${YELLOW}5)${RESET} 我不知道怎麼選，請給我建議"
echo ""

while true; do
  read -rp "  請輸入選項 [1-5]: " CHOICE
  case "$CHOICE" in
    1|2|3|4|5) break ;;
    *) echo -e "  ${YELLOW}⚠️  請輸入 1 到 5${RESET}" ;;
  esac
done

# ── 選項 5：推薦引導 ─────────────────────────────────────────────────────────
if [ "$CHOICE" = "5" ]; then
  clear
  echo -e "${BOLD}${CYAN}── 幫你選的建議 ──${RESET}"
  echo ""
  echo "  先問你幾個問題："
  echo ""

  read -rp "  1. 你趕不趕時間？今天就要裝好嗎？[y/N] " URGENT
  read -rp "  2. 預算重要嗎？一個月超過 NT\$100 你會考慮？[y/N] " COST_SENSITIVE
  read -rp "  3. 你熟 AWS 或 Google Cloud 嗎？[y/N] " CLOUD_FAMILIAR
  echo ""

  echo -e "${BOLD}${CYAN}── 我的建議 ──${RESET}"
  echo ""
  if [[ "${URGENT,,}" == "y" ]] && [[ "${COST_SENSITIVE,,}" == "y" ]]; then
    echo -e "  ${GREEN}➜ 選 Hetzner（選項 2）${RESET}"
    echo "  今天就想裝好又在意預算，Hetzner 最對你味。"
    echo "  申請 10 分鐘就能用，一個月 NT\$140。"
  elif [[ "${URGENT,,}" != "y" ]] && [[ "${COST_SENSITIVE,,}" == "y" ]]; then
    echo -e "  ${GREEN}➜ 選 Oracle Cloud（選項 1）${RESET}"
    echo "  可以等 1-3 天審核、又在意預算，Oracle 永久免費最值得等。"
    echo "  規格是四選最強的（4 OCPU / 24 GB）。"
  elif [[ "${CLOUD_FAMILIAR,,}" == "y" ]]; then
    echo -e "  ${GREEN}➜ 選 AWS（選項 3）或 GCP（選項 4）${RESET}"
    echo "  你熟的話用熟的平台最快，你同事維運也不會卡。"
  else
    echo -e "  ${GREEN}➜ 選 Oracle Cloud（選項 1）${RESET}"
    echo "  規格最好、完全免費，唯一缺點是審核 1-3 天。"
    echo "  如果等不了再選 Hetzner。"
  fi
  echo ""
  read -rp "  按 Enter 繼續選平台..."
  exec "$0"  # 重跑 start.sh
fi

# ── 選項 1：Oracle ───────────────────────────────────────────────────────────
if [ "$CHOICE" = "1" ]; then
  clear
  echo -e "${BOLD}${GREEN}── 你選了 Oracle Cloud ──${RESET}"
  echo ""
  echo -e "  ${BOLD}接下來在 Oracle Cloud Shell 跑：${RESET}"
  echo ""
  echo "  1. 到 https://cloud.oracle.com 登入"
  echo -e "  2. 右上角 ${CYAN}>_${RESET} 圖示開啟 Cloud Shell（不是左邊的選單，是右上角）"
  echo "  3. 等 Cloud Shell 啟動完成，把以下整段貼進去執行："
  echo ""
  echo -e "  ${BOLD}${GREEN}─────────── 複製這段 ───────────${RESET}"
  echo ""
  echo "  curl -fsSL ${REPO_URL}/setup_vm.sh \\"
  echo "    -o setup_vm.sh && chmod +x setup_vm.sh && bash setup_vm.sh"
  echo ""
  echo -e "  ${BOLD}${GREEN}──────────────────────────────${RESET}"
  echo ""
  echo -e "  ${DIM}完成後會給你 SSH 指令進 VM，之後 bootstrap.sh 會引導你${RESET}"
  echo -e "  ${DIM}設定 AI Key / LINE / Telegram / 課程存取碼。${RESET}"
  echo ""

# ── 選項 2：Hetzner（就地執行） ──────────────────────────────────────────────
elif [ "$CHOICE" = "2" ]; then
  clear
  echo -e "${BOLD}${GREEN}── 你選了 Hetzner Cloud ──${RESET}"
  echo ""
  echo "  Hetzner 的建 VM 流程就在你這台電腦跑（不用切到別的瀏覽器分頁）。"
  echo "  準備好以下資訊："
  echo ""
  echo -e "  ${CYAN}✓${RESET} Hetzner 帳號（還沒有請先到 https://console.hetzner.cloud 註冊）"
  echo -e "  ${CYAN}✓${RESET} 在 Hetzner 建立一個專案，取得 API Token"
  echo "    專案 → Security → API Tokens → Generate → 選 Read & Write"
  echo ""
  read -rp "  都準備好了？按 Enter 開始（Ctrl+C 中止）..."
  echo ""

  # 就地下載並跑 setup_vm_hetzner.sh
  echo -e "  ${DIM}▸ 下載 Hetzner VM 建立腳本...${RESET}"
  curl -fsSL "${REPO_URL}/setup_vm_hetzner.sh" -o setup_vm_hetzner.sh
  chmod +x setup_vm_hetzner.sh
  exec bash setup_vm_hetzner.sh

# ── 選項 3：AWS ───────────────────────────────────────────────────────────────
elif [ "$CHOICE" = "3" ]; then
  clear
  echo -e "${BOLD}${GREEN}── 你選了 AWS EC2 ──${RESET}"
  echo ""
  echo -e "  ${BOLD}接下來在 AWS CloudShell 跑：${RESET}"
  echo ""
  echo "  1. 到 https://console.aws.amazon.com 登入"
  echo -e "  2. 頂端工具列 ${CYAN}>_${RESET} 圖示開啟 CloudShell"
  echo "  3. 等 CloudShell 啟動完成，把以下整段貼進去執行："
  echo ""
  echo -e "  ${BOLD}${GREEN}─────────── 複製這段 ───────────${RESET}"
  echo ""
  echo "  curl -fsSL ${REPO_URL}/setup_vm_aws.sh \\"
  echo "    -o setup_vm_aws.sh && chmod +x setup_vm_aws.sh && bash setup_vm_aws.sh"
  echo ""
  echo -e "  ${BOLD}${GREEN}──────────────────────────────${RESET}"
  echo ""
  echo -e "  ${YELLOW}⚠️  AWS 約 NT\$900–1,100/月，不用時記得 Stop 實例${RESET}"
  echo ""

# ── 選項 4：GCP ───────────────────────────────────────────────────────────────
elif [ "$CHOICE" = "4" ]; then
  clear
  echo -e "${BOLD}${GREEN}── 你選了 GCP Compute ──${RESET}"
  echo ""
  echo -e "  ${BOLD}接下來在 GCP Cloud Shell 跑：${RESET}"
  echo ""
  echo "  1. 到 https://console.cloud.google.com 登入"
  echo -e "  2. 右上角 ${CYAN}>_${RESET} 圖示開啟 Cloud Shell"
  echo "  3. 等 Cloud Shell 啟動完成，把以下整段貼進去執行："
  echo ""
  echo -e "  ${BOLD}${GREEN}─────────── 複製這段 ───────────${RESET}"
  echo ""
  echo "  curl -fsSL ${REPO_URL}/setup_vm_gcp.sh \\"
  echo "    -o setup_vm_gcp.sh && chmod +x setup_vm_gcp.sh && bash setup_vm_gcp.sh"
  echo ""
  echo -e "  ${BOLD}${GREEN}──────────────────────────────${RESET}"
  echo ""
  echo -e "  ${YELLOW}⚠️  GCP 約 NT\$700–900/月，新帳號有 \$300 試用額度${RESET}"
  echo ""
fi

# ── 共同結尾 ─────────────────────────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${RESET}"
echo -e "  ${BOLD}下一步的流程（3 個階段）${RESET}"
echo -e "${BLUE}════════════════════════════════════════════${RESET}"
echo ""
echo "  Stage 1：建 VM（剛才你選的平台）"
echo "     ↓"
echo "  Stage 2：SSH 進 VM，跑 bootstrap.sh（自動下載 OpenClaw + 110 個 Skill）"
echo "     ↓"
echo "  Stage 3：到 LINE/Telegram 傳 /d01 做入學診斷"
echo ""
echo "  每個 stage 完成後都會告訴你下一步要做什麼，不會讓你迷路。"
echo ""
echo "  出問題？裝完 bootstrap 後可以跑診斷腳本："
echo "     curl -fsSL ${REPO_URL}/diagnose.sh -o diagnose.sh && sudo bash diagnose.sh"
echo ""
