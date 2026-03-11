#!/bin/bash
set -e

# =============================================================================
# 酒Ann × OpenClaw  VM 一鍵建立腳本
# 在 Oracle Cloud Shell 執行，自動完成：
#   1. 產生 SSH 金鑰
#   2. 取得帳號資訊（Compartment、VCN、Subnet、Image）
#   3. 建立 VM.Standard.A1.Flex（4 OCPU / 24GB / Ubuntu 22.04）
#   4. 開放 Security List Port 80
#   5. 輸出 SSH 連線指令 + 下一步的 bootstrap 指令
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

print_step() {
  echo ""
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════${NC}"
  echo ""
}
print_ok()   { echo -e "  ${GREEN}✅  $1${NC}"; }
print_warn() { echo -e "  ${YELLOW}⚠️   $1${NC}"; }
print_err()  { echo -e "  ${RED}❌  $1${NC}"; exit 1; }
print_info() { echo -e "  ${DIM}▸  $1${NC}"; }

# =============================================================================
# 開場
# =============================================================================
clear
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🦞  OpenClaw VM 一鍵建立程式          ║
  ║         酒Ann × OpenClaw_ecom 課程        ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER
echo -e "${NC}"
echo -e "  這個腳本會自動幫你完成："
echo ""
echo -e "  ${DIM}1.  產生 SSH 金鑰（登入 VM 用）${NC}"
echo -e "  ${DIM}2.  建立免費 VM（4 OCPU / 24GB RAM / Ubuntu 22.04）${NC}"
echo -e "  ${DIM}3.  開放 Port 80（LINE Webhook 需要）${NC}"
echo -e "  ${DIM}4.  輸出完整的安裝指令，直接複製貼上就好${NC}"
echo ""
echo -e "  ${YELLOW}預計執行時間：約 5 分鐘${NC}"
echo ""
read -p "  按 Enter 開始 ..."

# =============================================================================
# 確認在 Oracle Cloud Shell 環境
# =============================================================================
print_step "確認 OCI 環境"

if ! command -v oci &>/dev/null; then
  print_err "找不到 oci 指令，請確認你在 Oracle Cloud Shell 裡執行這個腳本"
fi

TENANCY_ID=$(oci iam tenancy get --tenancy-id "$OCI_TENANCY" --query 'data.id' --raw-output 2>/dev/null)
if [ -z "$TENANCY_ID" ]; then
  print_err "無法取得 Tenancy ID，請確認 Cloud Shell 已正確載入"
fi
print_ok "OCI 環境正常"

# =============================================================================
# 取得 Compartment ID（使用 Root Compartment）
# =============================================================================
print_step "取得帳號資訊"

echo -e "  📋 取得 Compartment..."
COMPARTMENT_ID="$TENANCY_ID"
print_ok "Compartment ID：${COMPARTMENT_ID:0:20}..."

# Availability Domain（取第一個）
echo -e "  📋 取得 Availability Domain..."
AD=$(oci iam availability-domain list \
  --compartment-id "$COMPARTMENT_ID" \
  --query 'data[0].name' \
  --raw-output 2>/dev/null)
if [ -z "$AD" ]; then
  print_err "無法取得 Availability Domain，請確認帳號已完成設定"
fi
print_ok "Availability Domain：${AD}"

# Ubuntu 22.04 ARM Image ID
echo -e "  📋 搜尋 Ubuntu 22.04 ARM 映像檔..."
IMAGE_ID=$(oci compute image list \
  --compartment-id "$COMPARTMENT_ID" \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "22.04" \
  --shape "VM.Standard.A1.Flex" \
  --sort-by TIMECREATED \
  --sort-order DESC \
  --query 'data[0].id' \
  --raw-output 2>/dev/null)

# 若指定 shape 找不到，不限 shape 再找一次
if [ -z "$IMAGE_ID" ]; then
  IMAGE_ID=$(oci compute image list \
    --compartment-id "$COMPARTMENT_ID" \
    --operating-system "Canonical Ubuntu" \
    --operating-system-version "22.04" \
    --sort-by TIMECREATED \
    --sort-order DESC \
    --query 'data[0].id' \
    --raw-output 2>/dev/null)
fi

if [ -z "$IMAGE_ID" ]; then
  print_err "找不到 Ubuntu 22.04 映像，請截圖傳給老師"
fi
print_ok "Ubuntu 22.04 ARM Image 找到"

# VCN（取第一個）
echo -e "  📋 取得 VCN..."
VCN_ID=$(oci network vcn list \
  --compartment-id "$COMPARTMENT_ID" \
  --query 'data[0].id' \
  --raw-output 2>/dev/null)
if [ -z "$VCN_ID" ]; then
  print_err "找不到 VCN，請確認帳號已完成初始設定"
fi
print_ok "VCN 找到"

# Subnet（取第一個 Public Subnet）
echo -e "  📋 取得 Subnet..."
SUBNET_ID=$(oci network subnet list \
  --compartment-id "$COMPARTMENT_ID" \
  --vcn-id "$VCN_ID" \
  --query 'data[?contains("display-name", `public`) || contains("display-name", `Public`)].id | [0]' \
  --raw-output 2>/dev/null)

# 若找不到 public subnet，取第一個
if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "null" ]; then
  SUBNET_ID=$(oci network subnet list \
    --compartment-id "$COMPARTMENT_ID" \
    --vcn-id "$VCN_ID" \
    --query 'data[0].id' \
    --raw-output 2>/dev/null)
fi
if [ -z "$SUBNET_ID" ]; then
  print_err "找不到 Subnet，請截圖傳給老師"
fi
print_ok "Public Subnet 找到"

# Security List ID
echo -e "  📋 取得 Security List..."
SECLIST_ID=$(oci network security-list list \
  --compartment-id "$COMPARTMENT_ID" \
  --vcn-id "$VCN_ID" \
  --query 'data[0].id' \
  --raw-output 2>/dev/null)
if [ -z "$SECLIST_ID" ]; then
  print_err "找不到 Security List"
fi
print_ok "Security List 找到"

# =============================================================================
# 產生 SSH 金鑰
# =============================================================================
print_step "產生 SSH 金鑰"

KEY_NAME="openclaw_key"
KEY_PATH="$HOME/.ssh/${KEY_NAME}"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ -f "$KEY_PATH" ]; then
  print_warn "偵測到已有 SSH 金鑰（${KEY_PATH}），直接使用現有金鑰"
else
  ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "openclaw" -q
  print_ok "SSH 金鑰產生完成"
fi

chmod 600 "$KEY_PATH"
chmod 644 "${KEY_PATH}.pub"
SSH_PUBLIC_KEY=$(cat "${KEY_PATH}.pub")
print_ok "公鑰已備妥"

# =============================================================================
# 確認建立資訊
# =============================================================================
print_step "確認 VM 建立資訊"

VM_NAME="openclaw-vm"
echo -e "  ${BOLD}VM 名稱：${NC}${VM_NAME}"
echo -e "  ${BOLD}規格：${NC}VM.Standard.A1.Flex（4 OCPU / 24 GB RAM）"
echo -e "  ${BOLD}系統：${NC}Ubuntu 22.04 ARM"
echo -e "  ${BOLD}Availability Domain：${NC}${AD}"
echo -e "  ${BOLD}SSH 金鑰：${NC}${KEY_PATH}"
echo ""
print_warn "免費方案每個帳號只有 4 OCPU 和 24GB 配額，一台 VM 就用完了"
echo ""
read -p "  確認建立？按 Enter 繼續（Ctrl+C 中止）..."

# =============================================================================
# 建立 VM
# =============================================================================
print_step "建立 VM（約 2–3 分鐘）"

echo -e "  🔨 正在建立 VM，請稍候..."

INSTANCE_JSON=$(oci compute instance launch \
  --compartment-id "$COMPARTMENT_ID" \
  --availability-domain "$AD" \
  --display-name "$VM_NAME" \
  --image-id "$IMAGE_ID" \
  --shape "VM.Standard.A1.Flex" \
  --shape-config '{"ocpus": 4, "memoryInGBs": 24}' \
  --subnet-id "$SUBNET_ID" \
  --assign-public-ip true \
  --ssh-authorized-keys-file "${KEY_PATH}.pub" \
  --metadata '{"user_data": ""}' \
  --wait-for-state RUNNING \
  --max-wait-seconds 300 \
  2>/dev/null)

if [ $? -ne 0 ] || [ -z "$INSTANCE_JSON" ]; then
  echo ""
  print_warn "VM 建立指令已發送，等待狀態更新..."
  sleep 30
  # 重新取得 Instance 資訊
  INSTANCE_JSON=$(oci compute instance list \
    --compartment-id "$COMPARTMENT_ID" \
    --display-name "$VM_NAME" \
    --lifecycle-state RUNNING \
    --query 'data[0]' \
    --raw-output 2>/dev/null || echo "")
fi

INSTANCE_ID=$(echo "$INSTANCE_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('id','') or d.get('data',{}).get('id',''))
except:
    print('')
" 2>/dev/null)

# 若還取不到，再查一次
if [ -z "$INSTANCE_ID" ]; then
  sleep 15
  INSTANCE_ID=$(oci compute instance list \
    --compartment-id "$COMPARTMENT_ID" \
    --display-name "$VM_NAME" \
    --query 'data[0].id' \
    --raw-output 2>/dev/null)
fi

if [ -z "$INSTANCE_ID" ]; then
  print_err "VM 建立失敗，請截圖傳給老師"
fi
print_ok "VM 建立成功"

# =============================================================================
# 取得 Public IP
# =============================================================================
echo -e "  📡 取得 VM 的 Public IP..."

PUBLIC_IP=""
for i in $(seq 1 20); do
  PUBLIC_IP=$(oci compute instance list-vnics \
    --instance-id "$INSTANCE_ID" \
    --query 'data[0]."public-ip"' \
    --raw-output 2>/dev/null)
  if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "null" ]; then
    break
  fi
  print_info "等待 IP 分配中（${i}/20）..."
  sleep 6
done

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "null" ]; then
  print_warn "自動取得 IP 失敗，請到 Oracle 控制台查看 VM 的 Public IP"
  PUBLIC_IP="YOUR_VM_IP"
else
  print_ok "Public IP：${PUBLIC_IP}"
fi

# =============================================================================
# 開放 Port 80（Security List）
# =============================================================================
print_step "開放 Port 80"

echo -e "  🔒 更新 Security List..."

# 取得現有的 Ingress Rules（避免覆蓋）
EXISTING_RULES=$(oci network security-list get \
  --security-list-id "$SECLIST_ID" \
  --query 'data."ingress-security-rules"' \
  --raw-output 2>/dev/null)

# 檢查 Port 80 是否已開放
if echo "$EXISTING_RULES" | python3 -c "
import sys, json
rules = json.load(sys.stdin)
for r in rules:
    tcp = r.get('tcp-options', {})
    dest = tcp.get('destination-port-range', {}) if tcp else {}
    if str(dest.get('min','')) == '80' and str(dest.get('max','')) == '80':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  print_ok "Port 80 已經開放，跳過此步驟"
else
  # 建立新規則清單（保留現有 + 加入 Port 80）
  NEW_RULES=$(echo "$EXISTING_RULES" | python3 -c "
import sys, json
rules = json.load(sys.stdin)
rules.append({
  'source': '0.0.0.0/0',
  'protocol': '6',
  'isStateless': False,
  'description': 'OpenClaw LINE Webhook HTTP',
  'tcpOptions': {
    'destinationPortRange': {'min': 80, 'max': 80}
  }
})
print(json.dumps(rules))
" 2>/dev/null)

  oci network security-list update \
    --security-list-id "$SECLIST_ID" \
    --ingress-security-rules "$NEW_RULES" \
    --force \
    2>/dev/null && print_ok "Port 80 開放完成" || \
    print_warn "Port 80 自動開放失敗，稍後請手動在 Oracle 控制台設定（STEP 5）"
fi

# =============================================================================
# 等待 VM SSH 就緒
# =============================================================================
print_step "等待 VM 啟動就緒"

echo -e "  ⏳ 等待 SSH 服務就緒（最長 3 分鐘）..."
SSH_READY=false
for i in $(seq 1 36); do
  if [ "$PUBLIC_IP" != "YOUR_VM_IP" ]; then
    if ssh -o StrictHostKeyChecking=no \
           -o ConnectTimeout=5 \
           -o BatchMode=yes \
           -i "$KEY_PATH" \
           "ubuntu@${PUBLIC_IP}" \
           "echo ok" &>/dev/null; then
      SSH_READY=true
      break
    fi
  fi
  print_info "等待中（${i}/36）..."
  sleep 5
done

if [ "$SSH_READY" = "true" ]; then
  print_ok "VM SSH 就緒，可以連線了"
else
  print_warn "SSH 尚未就緒，可能需要再等 1–2 分鐘，請稍後再嘗試連線"
fi

# =============================================================================
# 完成！輸出下一步指令
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}"
cat << 'DONE'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🎉  VM 建立完成！                     ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
DONE
echo -e "${NC}"

echo -e "  ${BOLD}── VM 資訊 ────────────────────────────────────${NC}"
echo ""
echo -e "  ${BOLD}VM 名稱：${NC}${VM_NAME}"
echo -e "  ${BOLD}Public IP：${NC}${CYAN}${PUBLIC_IP}${NC}"
echo -e "  ${BOLD}SSH 金鑰：${NC}${KEY_PATH}"
echo ""

echo -e "  ${BOLD}── 第一步：SSH 連線到 VM ──────────────────────${NC}"
echo ""
echo -e "  ${CYAN}複製以下指令，在這個 Cloud Shell 視窗貼上執行：${NC}"
echo ""
echo -e "  ${BOLD}${GREEN}ssh -i ${KEY_PATH} ubuntu@${PUBLIC_IP}${NC}"
echo ""

echo -e "  ${BOLD}── 第二步：一鍵安裝龍蝦 ──────────────────────${NC}"
echo ""
echo -e "  ${CYAN}進入 VM 後，貼上以下指令：${NC}"
echo ""
echo -e "  ${BOLD}${GREEN}curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/bootstrap.sh | sudo bash${NC}"
echo ""

echo -e "  ${BOLD}── 金鑰備份提醒 ────────────────────────────────${NC}"
echo ""
echo -e "  ${YELLOW}⚠️  請把 SSH 私鑰備份到你的電腦！${NC}"
echo -e "  ${DIM}在 Cloud Shell 點右上角選單 → Download file，輸入：${NC}"
echo -e "  ${DIM}${KEY_PATH}${NC}"
echo ""
echo -e "  ${DIM}（金鑰遺失就只能重建 VM，請一定要備份）${NC}"
echo ""
