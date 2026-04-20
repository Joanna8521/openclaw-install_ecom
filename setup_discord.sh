#!/bin/bash
set -euo pipefail
# =============================================================================
#  🦞  OpenClaw Discord 頻道設定腳本
#      電商+行銷+SEO 班
#
#  在 Oracle VM 上執行：
#    curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/setup_discord.sh | bash
#
#  完成後龍蝦會同時支援：
#    LINE（主要）、Telegram（可選）、Discord（可選）
# =============================================================================

# ── 顏色 ────────────────────────────────────────────────────────────────────
RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m'
CYAN='\033[0;36m';BOLD='\033[1m';DIM='\033[2m';NC='\033[0m'

ok()   { echo -e "  ${GREEN}✅${NC}  $1"; }
info() { echo -e "  ${DIM}▸${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠️ ${NC}  $1"; }
err()  { echo -e "  ${RED}❌${NC}  $1"; exit 1; }
section() {
  echo ""
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════${NC}"
  echo ""
}

# ── 必須是 root（才能寫 /root/.openclaw/.env 和改 config）─────────────────────
if [ "$EUID" -ne 0 ]; then
  err "請用 sudo 執行：sudo bash setup_discord.sh"
fi

# ── OpenClaw CLI 位置 ────────────────────────────────────────────────────────
INSTALL_DIR="/opt/openclaw"
OPENCLAW="/usr/bin/node ${INSTALL_DIR}/openclaw.mjs"

if [ ! -f "${INSTALL_DIR}/openclaw.mjs" ]; then
  err "找不到 ${INSTALL_DIR}/openclaw.mjs，請先執行 bootstrap.sh 完成基本安裝"
fi

# ── Banner ──────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🦞  OpenClaw Discord 頻道設定         ║
  ║         電商+行銷+SEO 班                  ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER
echo -e "${NC}"
echo "  開始前請先在 Discord Developer Portal 建立 Bot："
echo "  discord.com/developers/applications"
echo ""
echo "  需要完成的步驟（在瀏覽器操作，約 5 分鐘）："
echo "  1. New Application → 輸入名稱（例如：我的龍蝦）"
echo "  2. 左側 Bot → Reset Token → 複製 Token"
echo "  3. 同頁往下 → Privileged Gateway Intents → 開啟："
echo "     ✅ Message Content Intent（必開，否則龍蝦看不到訊息）"
echo "     ✅ Server Members Intent（建議開）"
echo "  4. 左側 OAuth2 → URL Generator"
echo "     Scopes 勾：bot + applications.commands"
echo "     Bot Permissions 勾：View Channels、Send Messages、"
echo "                        Read Message History、Embed Links、"
echo "                        Attach Files"
echo "  5. 複製產生的 URL，用瀏覽器開啟，把 Bot 加入你的 Server"
echo ""
read -rp "  以上步驟完成了嗎？[y/N] " ready
[[ "${ready,,}" == "y" ]] || { echo "  請先完成上方步驟後再執行此腳本"; exit 0; }

# ── STEP 1：確認 OpenClaw 有在跑 ─────────────────────────────────────────────
section "STEP 1｜確認 OpenClaw 狀態"

if systemctl is-active --quiet openclaw 2>/dev/null; then
  ok "OpenClaw 服務正在運行"
else
  warn "OpenClaw 服務未運行，嘗試啟動..."
  sudo systemctl start openclaw
  sleep 2
  if systemctl is-active --quiet openclaw 2>/dev/null; then
    ok "OpenClaw 已啟動"
  else
    err "OpenClaw 無法啟動，請先執行 bootstrap.sh 完成基本安裝"
  fi
fi

# ── STEP 2：輸入 Discord Bot Token ───────────────────────────────────────────
section "STEP 2｜設定 Discord Bot Token"

echo "  請貼上剛才複製的 Discord Bot Token："
echo "  （格式像：MTxxxxxxxxxxxxx.Gxxxxx.xxxxxxxxxxxxxxxxxxx）"
echo ""
read -rp "  Discord Bot Token: " DISCORD_TOKEN

# 基本格式驗證（Discord token 至少 59 字元）
if [[ ${#DISCORD_TOKEN} -lt 50 ]]; then
  err "Token 格式不對，請確認完整複製了 Bot Token"
fi
ok "Token 格式確認"

# 寫入環境變數到 /root/.openclaw/.env（OpenClaw 啟動時自動載入此檔）
ENV_FILE="/root/.openclaw/.env"
mkdir -p /root/.openclaw

if [[ ! -f "$ENV_FILE" ]]; then
  touch "$ENV_FILE"
  chmod 600 "$ENV_FILE"
fi

# 移除舊的 Discord token（如果有）
sed -i '/^DISCORD_BOT_TOKEN=/d' "$ENV_FILE" 2>/dev/null || true

# 寫入新 token
echo "DISCORD_BOT_TOKEN=${DISCORD_TOKEN}" >> "$ENV_FILE"
chmod 600 "$ENV_FILE"
ok "Token 已寫入 $ENV_FILE"

# ── STEP 3：設定 OpenClaw config ─────────────────────────────────────────────
section "STEP 3｜設定 OpenClaw Discord 頻道"

info "設定 Discord token 來源..."
$OPENCLAW config set channels.discord.token \
  --ref-provider default \
  --ref-source env \
  --ref-id DISCORD_BOT_TOKEN 2>/dev/null
ok "Token 來源設定完成"

info "啟用 Discord 頻道..."
$OPENCLAW config set channels.discord.enabled true --strict-json 2>/dev/null
ok "Discord 頻道已啟用"

# ── STEP 4：重啟服務 ──────────────────────────────────────────────────────────
section "STEP 4｜重啟 OpenClaw"

info "重啟服務中..."
sudo systemctl restart openclaw
sleep 3

if systemctl is-active --quiet openclaw 2>/dev/null; then
  ok "OpenClaw 重啟成功"
else
  err "重啟失敗，請執行 journalctl -u openclaw -n 30 查看錯誤"
fi

# ── STEP 5：配對 ──────────────────────────────────────────────────────────────
section "STEP 5｜配對 Discord Bot"

echo "  現在去 Discord，找到你剛建立的 Bot："
echo "  1. 確認 Server 設定 → Privacy Settings → Direct Messages 已開啟"
echo "     （允許 Server 成員傳送 DM，配對需要用到）"
echo "  2. 在 Discord 找到你的 Bot，傳任意訊息給它（例如：hi）"
echo "  3. Bot 會回覆一個 6 位數配對碼"
echo ""
read -rp "  請輸入配對碼（6位數字）: " PAIRING_CODE

# 驗證格式
if ! [[ "$PAIRING_CODE" =~ ^[0-9]{6}$ ]]; then
  err "配對碼格式不對，應為 6 位數字"
fi

info "執行配對..."
if $OPENCLAW pairing approve discord "$PAIRING_CODE" 2>/dev/null; then
  ok "Discord 配對成功！"
else
  echo ""
  warn "配對失敗，可能原因："
  echo "  • 配對碼已過期（有效期 1 小時，重新 DM Bot 取得新碼）"
  echo "  • Bot Token 填錯，請重新執行此腳本"
  echo "  • Discord Privacy Settings 未開啟 Direct Messages"
  echo ""
  echo "  手動配對指令："
  echo "  sudo node ${INSTALL_DIR}/openclaw.mjs pairing approve discord <配對碼>"
  exit 1
fi

# ── STEP 6：驗證 ──────────────────────────────────────────────────────────────
section "STEP 6｜驗證設定"

info "確認頻道狀態..."
sleep 1

# 嘗試列出已配對的頻道
if $OPENCLAW pairing list 2>/dev/null | grep -q "discord"; then
  ok "Discord 已出現在配對清單"
else
  warn "無法確認配對狀態，請在 Discord 傳訊息給 Bot 測試"
fi

# ── 完成畫面 ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
cat << 'SUCCESS'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🎉  Discord 設定完成！                ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
SUCCESS
echo -e "${NC}"

echo "  現在龍蝦支援三個頻道："
echo "  💚 LINE      → 主要推薦（台灣員工客戶都在這）"
echo "  ✈️  Telegram  → 可選替代"
echo "  🎮 Discord   → 可選替代（剛設定完成）"
echo ""
echo "  Discord 使用方式："
echo "  • DM Bot 直接使用（目前配對模式）"
echo "  • Server 頻道使用：需要 @mention Bot 名稱"
echo "  • 圖片截圖分析：直接傳圖 + 指令（例如 /e01 + 截圖）"
echo ""
echo "  ── 進階設定（可選）────────────────────────"
echo "  只想讓特定人使用（allowlist 模式）："
echo "  sudo node ${INSTALL_DIR}/openclaw.mjs config set channels.discord.dmPolicy allowlist"
echo ""
echo "  Server 特定頻道使用："
echo "  修改 ~/.openclaw/openclaw.json 加入 guilds 設定"
echo "  詳見：docs.openclaw.ai/channels/discord"
echo ""
echo "  ── 如果 Bot 沒反應 ─────────────────────────"
echo "  1. 確認 Message Content Intent 有開啟（Developer Portal）"
echo "  2. journalctl -u openclaw -n 30 --no-pager 查看錯誤"
echo "  3. sudo systemctl restart openclaw 重啟服務"
echo ""
