#!/bin/bash
set -e

# =============================================================================
# 酒Ann × OpenClaw  Hetzner VM 一鍵建立腳本
# 在你的電腦終端機執行（Mac / Windows WSL / Linux 皆可）
# 自動完成：
#   1. 輸入 Hetzner API Token
#   2. 產生 SSH 金鑰
#   3. 上傳 SSH 公鑰到 Hetzner
#   4. 建立 CX22（2 vCPU / 4GB RAM / 40GB / Ubuntu 22.04）
#   5. 等待 VM 就緒
#   6. 輸出 SSH 連線指令 + 下一步的 bootstrap 指令
#
# 費用：約 NT$130–150 / 月（€3.79/月）
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

HETZNER_API="https://api.hetzner.cloud/v1"
VM_NAME="openclaw-vm"
KEY_NAME="openclaw_key"
KEY_PATH="$HOME/.ssh/${KEY_NAME}"

# =============================================================================
# 確認環境
# =============================================================================
if ! command -v curl &>/dev/null; then
  print_err "找不到 curl，請先安裝：sudo apt-get install curl"
fi
if ! command -v ssh-keygen &>/dev/null; then
  print_err "找不到 ssh-keygen，請確認 SSH 已安裝"
fi
if ! command -v python3 &>/dev/null; then
  print_err "找不到 python3，請先安裝 Python 3"
fi

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
  ║         Hetzner Cloud 版                  ║
  ║         酒Ann × OpenClaw_ecom 課程        ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER
echo -e "${NC}"
echo -e "  這個腳本會自動幫你完成："
echo ""
echo -e "  ${DIM}1.  驗證 Hetzner API Token${NC}"
echo -e "  ${DIM}2.  產生 SSH 金鑰（登入 VM 用）${NC}"
echo -e "  ${DIM}3.  建立 VM（2 vCPU / 4GB RAM / Ubuntu 22.04）${NC}"
echo -e "  ${DIM}4.  開放 Port 80（LINE Webhook 需要）${NC}"
echo -e "  ${DIM}5.  輸出完整的安裝指令，直接複製貼上就好${NC}"
echo ""
echo -e "  ${YELLOW}費用：約 NT\$130–150 / 月（€3.79/月）${NC}"
echo -e "  ${YELLOW}預計執行時間：約 3 分鐘${NC}"
echo ""
echo -e "  ${BOLD}還沒有 Hetzner 帳號？${NC}"
echo -e "  ${DIM}1. 前往 https://www.hetzner.com/cloud 註冊${NC}"
echo -e "  ${DIM}2. 建立新專案（例如 openclaw）${NC}"
echo -e "  ${DIM}3. 進入專案 → 右上角 Security → API Tokens → Generate API Token${NC}"
echo -e "  ${DIM}4. 權限選「Read & Write」，複製 Token 備用${NC}"
echo ""
read -p "  按 Enter 開始 ..."

# =============================================================================
# 輸入並驗證 API Token
# =============================================================================
print_step "輸入 Hetzner API Token"

echo -e "  ${DIM}Token 在 Hetzner 控制台 → 你的專案 → Security → API Tokens${NC}"
echo ""

while true; do
  read -s -p "  ➤ 貼上你的 API Token：" HETZNER_TOKEN
  echo ""

  if [ -z "$HETZNER_TOKEN" ]; then
    print_warn "Token 不能為空，請重新輸入"
    continue
  fi

  # 驗證 Token
  print_info "驗證 Token 中..."
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $HETZNER_TOKEN" \
    "$HETZNER_API/servers" 2>/dev/null)

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)

  if [ "$HTTP_CODE" = "200" ]; then
    print_ok "API Token 驗證成功"
    break
  elif [ "$HTTP_CODE" = "401" ]; then
    print_warn "Token 無效或已過期，請重新貼上"
  else
    print_warn "驗證失敗（HTTP $HTTP_CODE），請確認網路連線後重試"
  fi
done

# =============================================================================
# 產生 SSH 金鑰
# =============================================================================
print_step "產生 SSH 金鑰"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ -f "$KEY_PATH" ]; then
  print_warn "偵測到已有 SSH 金鑰（${KEY_PATH}），直接使用"
else
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "openclaw" -q
  print_ok "SSH 金鑰產生完成（ed25519）"
fi

chmod 600 "$KEY_PATH"
chmod 644 "${KEY_PATH}.pub"
SSH_PUBLIC_KEY=$(cat "${KEY_PATH}.pub")
print_ok "公鑰已備妥"

# =============================================================================
# 上傳 SSH 公鑰到 Hetzner
# =============================================================================
print_step "上傳 SSH 公鑰"

print_info "檢查是否已有同名金鑰..."

# 先查是否已上傳過
EXISTING_KEY_ID=$(curl -s \
  -H "Authorization: Bearer $HETZNER_TOKEN" \
  "$HETZNER_API/ssh_keys" 2>/dev/null | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for k in data.get('ssh_keys', []):
    if k.get('name') == 'openclaw_key':
        print(k['id'])
        break
" 2>/dev/null)

if [ -n "$EXISTING_KEY_ID" ]; then
  SSH_KEY_ID="$EXISTING_KEY_ID"
  print_ok "使用已上傳的 SSH 金鑰（ID: ${SSH_KEY_ID}）"
else
  UPLOAD_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $HETZNER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"openclaw_key\", \"public_key\": \"${SSH_PUBLIC_KEY}\"}" \
    "$HETZNER_API/ssh_keys" 2>/dev/null)

  SSH_KEY_ID=$(echo "$UPLOAD_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('ssh_key', {}).get('id', ''))
" 2>/dev/null)

  if [ -z "$SSH_KEY_ID" ]; then
    print_err "SSH 金鑰上傳失敗，請截圖傳給老師"
  fi
  print_ok "SSH 公鑰上傳完成（ID: ${SSH_KEY_ID}）"
fi

# =============================================================================
# 確認建立資訊
# =============================================================================
print_step "確認 VM 建立資訊"

echo -e "  ${BOLD}VM 名稱：${NC}${VM_NAME}"
echo -e "  ${BOLD}規格：${NC}CX22（2 vCPU / 4 GB RAM / 40 GB SSD）"
echo -e "  ${BOLD}系統：${NC}Ubuntu 22.04 LTS"
echo -e "  ${BOLD}位置：${NC}新加坡（sin）— 台灣連線最快"
echo -e "  ${BOLD}費用：${NC}€3.79 / 月（約 NT\$140）"
echo ""
read -p "  確認建立？按 Enter 繼續（Ctrl+C 中止）..."

# =============================================================================
# 建立 VM
# =============================================================================
print_step "建立 VM（約 1–2 分鐘）"

echo -e "  🔨 送出建立請求..."

CREATE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $HETZNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${VM_NAME}\",
    \"server_type\": \"cx22\",
    \"image\": \"ubuntu-22.04\",
    \"location\": \"sin\",
    \"ssh_keys\": [${SSH_KEY_ID}],
    \"public_net\": {
      \"enable_ipv4\": true,
      \"enable_ipv6\": false
    },
    \"labels\": {
      \"project\": \"openclaw\",
      \"course\": \"aiclaw-ecom\"
    }
  }" \
  "$HETZNER_API/servers" 2>/dev/null)

SERVER_ID=$(echo "$CREATE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('server', {}).get('id', ''))
" 2>/dev/null)

if [ -z "$SERVER_ID" ]; then
  # 可能已有同名 VM
  ERROR_MSG=$(echo "$CREATE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
err = data.get('error', {})
print(err.get('code',''), err.get('message',''))
" 2>/dev/null)

  if echo "$ERROR_MSG" | grep -q "uniqueness_error"; then
    print_warn "偵測到已有名為 ${VM_NAME} 的 VM，取得現有 VM 資訊..."
    SERVER_ID=$(curl -s \
      -H "Authorization: Bearer $HETZNER_TOKEN" \
      "$HETZNER_API/servers?name=${VM_NAME}" 2>/dev/null | \
      python3 -c "
import sys, json
data = json.load(sys.stdin)
servers = data.get('servers', [])
print(servers[0]['id'] if servers else '')
" 2>/dev/null)
  else
    print_err "VM 建立失敗：${ERROR_MSG}，請截圖傳給老師"
  fi
fi

print_ok "VM 建立成功（ID: ${SERVER_ID}）"

# =============================================================================
# 等待 VM 就緒 + 取得 IP
# =============================================================================
print_step "等待 VM 啟動就緒"

echo -e "  ⏳ 等待 VM 進入 running 狀態..."
PUBLIC_IP=""

for i in $(seq 1 30); do
  SERVER_INFO=$(curl -s \
    -H "Authorization: Bearer $HETZNER_TOKEN" \
    "$HETZNER_API/servers/${SERVER_ID}" 2>/dev/null)

  STATUS=$(echo "$SERVER_INFO" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('server', {}).get('status', ''))
" 2>/dev/null)

  IP=$(echo "$SERVER_INFO" | python3 -c "
import sys, json
data = json.load(sys.stdin)
net = data.get('server', {}).get('public_net', {})
ipv4 = net.get('ipv4', {})
print(ipv4.get('ip', ''))
" 2>/dev/null)

  if [ "$STATUS" = "running" ] && [ -n "$IP" ]; then
    PUBLIC_IP="$IP"
    print_ok "VM 狀態：running"
    print_ok "Public IP：${PUBLIC_IP}"
    break
  fi

  print_info "狀態：${STATUS:-啟動中}（${i}/30）..."
  sleep 6
done

if [ -z "$PUBLIC_IP" ]; then
  print_err "取得 IP 失敗，請到 Hetzner 控制台查看 VM 的 IP 後手動連線"
fi

# =============================================================================
# 設定防火牆（開放 Port 80 / 443）
# =============================================================================
print_step "設定防火牆規則"

echo -e "  🔒 建立防火牆規則（Port 22 / 80 / 443）..."

FW_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $HETZNER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"openclaw-firewall\",
    \"rules\": [
      {
        \"direction\": \"in\",
        \"protocol\": \"tcp\",
        \"port\": \"22\",
        \"source_ips\": [\"0.0.0.0/0\"],
        \"description\": \"SSH\"
      },
      {
        \"direction\": \"in\",
        \"protocol\": \"tcp\",
        \"port\": \"80\",
        \"source_ips\": [\"0.0.0.0/0\"],
        \"description\": \"LINE Webhook HTTP\"
      },
      {
        \"direction\": \"in\",
        \"protocol\": \"tcp\",
        \"port\": \"443\",
        \"source_ips\": [\"0.0.0.0/0\"],
        \"description\": \"HTTPS\"
      }
    ],
    \"apply_to\": [{\"type\": \"server\", \"server\": {\"id\": ${SERVER_ID}}}]
  }" \
  "$HETZNER_API/firewalls" 2>/dev/null)

FW_ID=$(echo "$FW_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('firewall', {}).get('id', ''))
" 2>/dev/null)

if [ -n "$FW_ID" ]; then
  print_ok "防火牆建立完成（Port 22 / 80 / 443 已開放）"
else
  # 可能防火牆名稱重複，直接套用到 server
  print_warn "防火牆建立遇到問題，Port 80/443 可能需要手動在 Hetzner 控制台設定"
fi

# =============================================================================
# 等待 SSH 就緒
# =============================================================================
print_step "等待 SSH 服務就緒"

echo -e "  ⏳ 等待 SSH 就緒（最長 2 分鐘）..."
SSH_READY=false
for i in $(seq 1 24); do
  if ssh -o StrictHostKeyChecking=no \
         -o ConnectTimeout=5 \
         -o BatchMode=yes \
         -i "$KEY_PATH" \
         "root@${PUBLIC_IP}" \
         "echo ok" &>/dev/null 2>&1; then
    SSH_READY=true
    break
  fi
  print_info "等待中（${i}/24）..."
  sleep 5
done

if [ "$SSH_READY" = "true" ]; then
  print_ok "SSH 就緒，可以連線了"
else
  print_warn "SSH 尚未就緒，可能需要再等 1 分鐘，請稍後再嘗試連線"
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
echo -e "  ${BOLD}規格：${NC}CX22（2 vCPU / 4 GB RAM）"
echo -e "  ${BOLD}費用：${NC}€3.79 / 月（Hetzner 控制台可隨時關機停止計費）"
echo ""

echo -e "  ${BOLD}── 第一步：SSH 連線到 VM ──────────────────────${NC}"
echo ""
echo -e "  ${CYAN}複製以下指令貼上執行：${NC}"
echo ""
echo -e "  ${BOLD}${GREEN}ssh -i ${KEY_PATH} root@${PUBLIC_IP}${NC}"
echo ""
echo -e "  ${DIM}（Hetzner 預設用 root，不是 ubuntu）${NC}"
echo ""

echo -e "  ${BOLD}── 第二步：一鍵安裝龍蝦 ──────────────────────${NC}"
echo ""
echo -e "  ${CYAN}進入 VM 後，貼上以下指令：${NC}"
echo ""
echo -e "  ${YELLOW}⚠️  必須用下面這個指令（不可用 curl | sudo bash，會吞掉互動輸入）：${NC}"
echo ""
echo -e "  ${BOLD}${GREEN}curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/bootstrap.sh \\${NC}"
echo -e "  ${BOLD}${GREEN}  -o bootstrap.sh && chmod +x bootstrap.sh && sudo ./bootstrap.sh${NC}"
echo ""

echo -e "  ${BOLD}── 金鑰備份提醒 ────────────────────────────────${NC}"
echo ""
echo -e "  ${YELLOW}⚠️  請把 SSH 私鑰備份起來！${NC}"
echo -e "  ${DIM}私鑰路徑：${KEY_PATH}${NC}"
echo -e "  ${DIM}遺失後只能重建 VM，請一定要備份到安全的地方。${NC}"
echo ""

echo -e "  ${BOLD}── 費用管理提醒 ────────────────────────────────${NC}"
echo ""
echo -e "  ${DIM}• 關機不等於停止計費，VM 存在就會計費${NC}"
echo -e "  ${DIM}• 真的不用時請到 Hetzner 控制台刪除 VM（Delete Server）${NC}"
echo -e "  ${DIM}• 控制台網址：https://console.hetzner.cloud${NC}"
echo ""
