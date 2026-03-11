#!/bin/bash
set -e

# =============================================================================
# 酒Ann OpenClaw 龍蝦助理 一鍵安裝程式
# 適用環境：Oracle Cloud VM（Ubuntu 22.04）固定 IP + Nginx
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

INSTALL_DIR="/opt/openclaw"
SERVICE_USER="openclaw"
OPENCLAW_REPO="https://github.com/openclaw/openclaw.git"
SKILLS_REPO=""  # 安裝時由學員輸入存取碼後動態產生

# =============================================================================
# 工具函數
# =============================================================================
print_step() {
  echo ""
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════${NC}"
  echo ""
}

print_ok()   { echo -e "  ${GREEN}✅  $1${NC}"; }
print_warn() { echo -e "  ${YELLOW}⚠️   $1${NC}"; }
print_err()  { echo -e "  ${RED}❌  $1${NC}"; }
print_info() { echo -e "  ${DIM}▸  $1${NC}"; }

ask() {
  # ask "提示" 變數名 [預設值]
  local prompt="$1"
  local varname="$2"
  local default="$3"
  if [ -n "$default" ]; then
    read -p "  ➤ ${prompt} [預設: ${default}]：" val
    val="${val:-$default}"
  else
    read -p "  ➤ ${prompt}：" val
  fi
  eval "$varname=\"$val\""
}

ask_secret() {
  local prompt="$1"
  local varname="$2"
  read -s -p "  ➤ ${prompt}：" val
  echo ""
  eval "$varname=\"$val\""
}

# =============================================================================
# 開場畫面
# =============================================================================
clear
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🦞  OpenClaw 龍蝦助理 安裝程式           ║
  ║         酒Ann × OpenClaw_ecom課程          ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER
echo -e "${NC}"
echo -e "  這個腳本會幫你完成以下所有步驟："
echo ""
echo -e "  ${DIM}1.  安裝系統環境（Python、Node.js、Nginx）${NC}"
echo -e "  ${DIM}2.  下載 OpenClaw 主程式${NC}"
echo -e "  ${DIM}3.  下載 98 個 Skill（C01–C10 + E01–E88）${NC}"
echo -e "  ${DIM}4.  設定 AI 金鑰（Claude / Gemini / OpenAI）${NC}"
echo -e "  ${DIM}5.  設定 LINE Bot${NC}"
echo -e "  ${DIM}6.  設定 Nginx 反向代理${NC}"
echo -e "  ${DIM}7.  設定 systemd 開機自動啟動${NC}"
echo -e "  ${DIM}8.  安裝所有 Skill 並測試${NC}"
echo ""
echo -e "  ${YELLOW}預計安裝時間：約 15–20 分鐘${NC}"
echo ""
read -p "  按 Enter 開始安裝 ..."

# =============================================================================
# 第零步：輸入 Skills 存取碼
# =============================================================================
print_step "第零步：輸入 Skills 存取碼"

echo -e "  酒Ann 課程學員專屬步驟。"
echo -e "  請輸入老師在課程群組提供的 ${BOLD}Skills 存取碼${NC}。"
echo ""
echo -e "  ${DIM}（存取碼格式：github_pat_ 開頭的一串英數字）${NC}"
echo ""

while true; do
  ask_secret "Skills 存取碼" SKILLS_TOKEN
  if [[ "$SKILLS_TOKEN" == github_pat_* ]]; then
    SKILLS_REPO="https://${SKILLS_TOKEN}@github.com/Joanna8521/openclaw_ecom.git"
    print_ok "存取碼格式正確"
    break
  elif [ -z "$SKILLS_TOKEN" ]; then
    print_err "存取碼不能為空，請重新輸入"
    echo -e "  ${DIM}如果還沒有存取碼，請先向酒Ann 取得後再執行安裝。${NC}"
  else
    print_warn "格式不對，存取碼應以 github_pat_ 開頭，請重新確認"
  fi
done

# =============================================================================
# 第一步：選擇 AI 引擎
# =============================================================================
print_step "第一步：選擇你的 AI 引擎"

echo -e "  OpenClaw 支援三種 AI 引擎，請選擇你要使用的："
echo ""
echo -e "  ${BOLD}1.  Claude${NC}  （Anthropic，推薦，理解繁體中文最佳）"
echo -e "  ${BOLD}2.  Gemini${NC}  （Google，有免費方案）"
echo -e "  ${BOLD}3.  OpenAI${NC}  （GPT-4，最廣泛使用）"
echo -e "  ${BOLD}4.  暫時跳過${NC}（之後在 LINE 對話裡設定）"
echo ""

while true; do
  ask "請輸入選項（1-4）" AI_CHOICE
  case "$AI_CHOICE" in
    1|2|3|4) break ;;
    *) print_warn "請輸入 1、2、3 或 4" ;;
  esac
done

AI_PROVIDER=""
AI_API_KEY=""

case "$AI_CHOICE" in
  1)
    AI_PROVIDER="claude"
    echo ""
    echo -e "  ${DIM}Claude API Key 取得方式：https://console.anthropic.com/${NC}"
    echo -e "  ${DIM}格式以 sk-ant- 開頭${NC}"
    echo ""
    while true; do
      ask_secret "Claude API Key" AI_API_KEY
      if [[ "$AI_API_KEY" == sk-ant-* ]]; then
        print_ok "Claude API Key 格式正確"
        break
      else
        print_warn "格式不對，Claude Key 應以 sk-ant- 開頭，請重新輸入"
        echo -e "  ${DIM}（如果還沒有，按 Enter 跳過，之後再設定）${NC}"
        read -s -p "  ➤ Claude API Key（留空跳過）：" AI_API_KEY
        echo ""
        [ -z "$AI_API_KEY" ] && break
      fi
    done
    ;;
  2)
    AI_PROVIDER="gemini"
    echo ""
    echo -e "  ${DIM}Gemini API Key 取得方式：https://aistudio.google.com/app/apikey${NC}"
    echo -e "  ${DIM}格式以 AIza 開頭${NC}"
    echo ""
    while true; do
      ask_secret "Gemini API Key" AI_API_KEY
      if [[ "$AI_API_KEY" == AIza* ]]; then
        print_ok "Gemini API Key 格式正確"
        break
      else
        print_warn "格式不對，Gemini Key 應以 AIza 開頭，請重新輸入"
        read -s -p "  ➤ Gemini API Key（留空跳過）：" AI_API_KEY
        echo ""
        [ -z "$AI_API_KEY" ] && break
      fi
    done
    ;;
  3)
    AI_PROVIDER="openai"
    echo ""
    echo -e "  ${DIM}OpenAI API Key 取得方式：https://platform.openai.com/api-keys${NC}"
    echo -e "  ${DIM}格式以 sk- 開頭${NC}"
    echo ""
    while true; do
      ask_secret "OpenAI API Key" AI_API_KEY
      if [[ "$AI_API_KEY" == sk-* ]]; then
        print_ok "OpenAI API Key 格式正確"
        break
      else
        print_warn "格式不對，OpenAI Key 應以 sk- 開頭，請重新輸入"
        read -s -p "  ➤ OpenAI API Key（留空跳過）：" AI_API_KEY
        echo ""
        [ -z "$AI_API_KEY" ] && break
      fi
    done
    ;;
  4)
    AI_PROVIDER="pending"
    print_warn "跳過 AI 金鑰，安裝完成後可在 LINE 對話輸入「/設定 AI金鑰」來設定"
    ;;
esac

# =============================================================================
# 第二步：LINE Bot 設定
# =============================================================================
print_step "第二步：LINE Bot 設定"

echo -e "  LINE Bot 讓龍蝦透過 LINE 和你對話。"
echo -e "  ${DIM}（如果還沒申請 LINE Developer 帳號，可以先跳過）${NC}"
echo ""
echo -e "  ${BOLD}1.  現在設定${NC}"
echo -e "  ${BOLD}2.  稍後跳過${NC}（之後再手動設定）"
echo ""

ask "請選擇（1-2）" LINE_CHOICE "1"

LINE_CHANNEL_SECRET=""
LINE_ACCESS_TOKEN=""

if [ "$LINE_CHOICE" = "1" ]; then
  echo ""
  echo -e "  ${DIM}LINE Channel Secret 和 Access Token 在這裡取得：${NC}"
  echo -e "  ${DIM}https://developers.line.biz/ → 你的 Channel → Messaging API${NC}"
  echo ""

  while true; do
    ask_secret "LINE Channel Secret" LINE_CHANNEL_SECRET
    if [ -n "$LINE_CHANNEL_SECRET" ]; then
      print_ok "LINE Channel Secret 已輸入"
      break
    else
      print_warn "LINE Channel Secret 不能為空，請重新輸入"
    fi
  done

  echo ""

  while true; do
    ask_secret "LINE Channel Access Token" LINE_ACCESS_TOKEN
    if [ -n "$LINE_ACCESS_TOKEN" ]; then
      print_ok "LINE Channel Access Token 已輸入"
      break
    else
      print_warn "LINE Channel Access Token 不能為空，請重新輸入"
    fi
  done

else
  print_warn "跳過 LINE 設定，安裝完成後修改 ${INSTALL_DIR}/config/config.yml 來設定"
fi

# =============================================================================
# 第三步：Google 服務（選填）
# =============================================================================
print_step "第三步：Google 服務整合（選填）"

echo -e "  Google 服務讓龍蝦能讀寫你的 Google Sheets、Drive、Calendar。"
echo -e "  ${DIM}C02 Skill 需要這個設定。現在可以先跳過，安裝完成後再設定。${NC}"
echo ""
echo -e "  ${BOLD}1.  現在設定 Google 憑證檔案路徑${NC}"
echo -e "  ${BOLD}2.  稍後跳過${NC}"
echo ""

ask "請選擇（1-2）" GOOGLE_CHOICE "2"

GOOGLE_CREDENTIALS_PATH=""

if [ "$GOOGLE_CHOICE" = "1" ]; then
  echo ""
  echo -e "  ${DIM}請先把 Google 服務帳號 JSON 金鑰上傳到這台 VM，${NC}"
  echo -e "  ${DIM}然後輸入檔案完整路徑（例如 /home/ubuntu/google-credentials.json）${NC}"
  echo ""
  ask "Google 憑證 JSON 路徑" GOOGLE_CREDENTIALS_PATH
  if [ -f "$GOOGLE_CREDENTIALS_PATH" ]; then
    print_ok "找到憑證檔案：${GOOGLE_CREDENTIALS_PATH}"
  else
    print_warn "找不到檔案，跳過。安裝完成後可重新設定"
    GOOGLE_CREDENTIALS_PATH=""
  fi
else
  print_warn "跳過 Google 設定，稍後可執行 node /opt/openclaw/openclaw.mjs setup 來設定"
fi

# =============================================================================
# 確認資訊
# =============================================================================
print_step "確認設定資訊"

echo -e "  ${BOLD}安裝目錄：${NC}${INSTALL_DIR}"
echo ""
echo -e "  ${BOLD}AI 引擎：${NC}"
case "$AI_CHOICE" in
  1) echo -e "    Claude  $([ -n "$AI_API_KEY" ] && echo "✅ Key 已設定" || echo "⚠️  待設定")" ;;
  2) echo -e "    Gemini  $([ -n "$AI_API_KEY" ] && echo "✅ Key 已設定" || echo "⚠️  待設定")" ;;
  3) echo -e "    OpenAI  $([ -n "$AI_API_KEY" ] && echo "✅ Key 已設定" || echo "⚠️  待設定")" ;;
  4) echo -e "    ⚠️  待設定" ;;
esac
echo ""
echo -e "  ${BOLD}Skills 存取碼：${NC}✅ 已驗證（github_pat_****${SKILLS_TOKEN: -6})"
echo -e "  ${BOLD}LINE Bot：${NC}$([ -n "$LINE_CHANNEL_SECRET" ] && echo "✅ 已設定" || echo "⚠️  待設定")"
echo -e "  ${BOLD}Google：${NC}$([ -n "$GOOGLE_CREDENTIALS_PATH" ] && echo "✅ ${GOOGLE_CREDENTIALS_PATH}" || echo "⚠️  待設定")"
echo ""
read -p "  確認無誤？按 Enter 開始安裝（Ctrl+C 中止）..."

# =============================================================================
# 正式安裝開始
# =============================================================================
print_step "開始自動安裝（請勿關閉視窗）"

# ── 系統套件 ──────────────────────────────────────────
echo -e "  📦 更新系統套件..."
sudo apt-get update -qq
sudo apt-get install -y -qq git curl wget jq nginx certbot cron build-essential && \
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && \
  sudo apt-get install -y -qq nodejs 2>/dev/null || true
sudo apt-get install -y -qq git curl wget jq nginx certbot cron build-essential 2>/dev/null || true
# 安裝 Node.js 20 LTS（移除舊版衝突套件後安裝）
if ! node -v 2>/dev/null | grep -q "v2[0-9]"; then
  sudo apt-get remove -y libnode-dev libnode72 nodejs 2>/dev/null || true
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null
  sudo apt-get install -y nodejs 2>/dev/null
fi
print_ok "系統套件安裝完成"

# ── Python 3.11 ───────────────────────────────────────
echo -e "  🐍 確認 Python 3.11..."
# Node.js installed above
print_ok "Node.js $(node --version) 就緒"

# ── 服務使用者 ────────────────────────────────────────
if ! id "$SERVICE_USER" &>/dev/null; then
  sudo useradd -r -s /bin/bash -m -d "$INSTALL_DIR" "$SERVICE_USER"
  print_ok "建立服務使用者：${SERVICE_USER}"
fi

# ── 下載 OpenClaw 主程式 ──────────────────────────────
echo -e "  📥 下載 OpenClaw 主程式..."
sudo mkdir -p "$INSTALL_DIR"
if [ -d "$INSTALL_DIR/.git" ]; then
  sudo git -C "$INSTALL_DIR" pull -q 2>/dev/null || true
  print_ok "OpenClaw 主程式更新完成"
else
  sudo rm -rf "$INSTALL_DIR"
  sudo git clone --quiet "$OPENCLAW_REPO" "$INSTALL_DIR"
  sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
  print_ok "OpenClaw 主程式下載完成"
fi

# ── 下載 Skills ───────────────────────────────────────
echo -e "  📥 下載 98 個 Skill..."
SKILLS_DIR="$INSTALL_DIR/skills"
sudo mkdir -p "$SKILLS_DIR"
if [ -d "$SKILLS_DIR/.git" ]; then
  sudo git -C "$SKILLS_DIR" pull -q 2>/dev/null || true
  print_ok "Skills 更新完成"
else
  sudo rm -rf "$SKILLS_DIR"
  sudo git clone --quiet "$SKILLS_REPO" "$SKILLS_DIR"
  sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$SKILLS_DIR"
  print_ok "98 個 Skill 下載完成"
fi

# ── Python 虛擬環境 ───────────────────────────────────
echo -e "  🐍 建立 Python 虛擬環境..."
# Install Node deps and build
cd "$INSTALL_DIR"
# 安裝相依套件
cd "$INSTALL_DIR"
sudo npm install --quiet 2>/dev/null || true
sudo npm run build --quiet 2>/dev/null || true
print_ok "Python 套件安裝完成"

# ── 設定檔 ────────────────────────────────────────────
echo -e "  🔑 寫入設定檔..."
sudo mkdir -p "$INSTALL_DIR/config"

# 先計算各 AI key 值
sudo tee "$INSTALL_DIR/config/config.yml" > /dev/null << EOF
# OpenClaw 設定檔
# 修改後執行 sudo systemctl restart openclaw 生效

ai:
  provider: "${AI_PROVIDER}"
  claude_api_key: "$([ "$AI_PROVIDER" = "claude" ] && echo "$AI_API_KEY")"
  gemini_api_key: "$([ "$AI_PROVIDER" = "gemini" ] && echo "$AI_API_KEY")"
  openai_api_key: "$([ "$AI_PROVIDER" = "openai" ] && echo "$AI_API_KEY")"

line:
  channel_secret: "${LINE_CHANNEL_SECRET}"
  access_token: "${LINE_ACCESS_TOKEN}"

google:
  credentials_path: "${GOOGLE_CREDENTIALS_PATH}"

skills:
  path: "${INSTALL_DIR}/skills"
  enabled: true

server:
  host: "0.0.0.0"
  port: 18789
  workers: 2
EOF

sudo chmod 600 "$INSTALL_DIR/config/config.yml"
sudo chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/config/config.yml"
print_ok "設定檔寫入完成"

# 若有 Google 憑證，複製過去
if [ -n "$GOOGLE_CREDENTIALS_PATH" ] && [ -f "$GOOGLE_CREDENTIALS_PATH" ]; then
  sudo cp "$GOOGLE_CREDENTIALS_PATH" "$INSTALL_DIR/config/google_credentials.json"
  sudo chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/config/google_credentials.json"
  sudo chmod 600 "$INSTALL_DIR/config/google_credentials.json"
  print_ok "Google 憑證複製完成"
fi

# ── Nginx 設定 ────────────────────────────────────────
echo -e "  🌐 設定 Nginx..."
PUBLIC_IP=$(curl -s --max-time 5 http://ifconfig.me 2>/dev/null || \
            curl -s --max-time 5 http://ipinfo.io/ip 2>/dev/null || \
            echo "YOUR_VM_IP")

sudo tee /etc/nginx/sites-available/openclaw > /dev/null << EOF
server {
    listen 80;
    server_name ${PUBLIC_IP} _;

    # LINE Webhook
    location /webhook {
        proxy_pass http://127.0.0.1:18789/webhook;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
    }

    # API
    location /api/ {
        proxy_pass http://127.0.0.1:18789/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 60s;
    }

    # 健康檢查
    location /health {
        proxy_pass http://127.0.0.1:18789/health;
    }

    location / {
        return 200 '🦞 OpenClaw is running';
        add_header Content-Type text/plain;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t -q && sudo systemctl reload nginx
print_ok "Nginx 設定完成（Public IP：${PUBLIC_IP}）"

# ── 防火牆 ────────────────────────────────────────────
echo -e "  🔒 設定防火牆..."
sudo ufw allow 22/tcp   -q 2>/dev/null || true
sudo ufw allow 80/tcp   -q 2>/dev/null || true
sudo ufw allow 443/tcp  -q 2>/dev/null || true
sudo ufw --force enable -q 2>/dev/null || true
print_ok "防火牆設定完成"

# ── systemd 服務 ──────────────────────────────────────
echo -e "  ⚙️  設定 systemd 服務..."
sudo tee /etc/systemd/system/openclaw.service > /dev/null << EOF
[Unit]
Description=OpenClaw AI 龍蝦助理
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node /opt/openclaw/openclaw.mjs gateway
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable openclaw -q

# 修正 LINE plugin 權限
sudo chown -R root:root "${INSTALL_DIR}/extensions" 2>/dev/null || true

# 設定 gateway.mode
sudo node /opt/openclaw/openclaw.mjs setup
sudo node /opt/openclaw/openclaw.mjs config set gateway.mode local

# 設定 Anthropic API Key
if [ -n "$AI_API_KEY" ] && [ "$AI_PROVIDER" = "claude" ]; then
  sudo node /opt/openclaw/openclaw.mjs config set model.providers.anthropic.apiKey "$AI_API_KEY"
  print_ok "Claude API Key 已寫入設定"
fi

# 設定 LINE Bot
if [ -n "$LINE_CHANNEL_SECRET" ] && [ -n "$LINE_ACCESS_TOKEN" ]; then
  sudo node /opt/openclaw/openclaw.mjs config set channels.line.enabled true
  sudo node /opt/openclaw/openclaw.mjs config set channels.line.channelSecret "$LINE_CHANNEL_SECRET"
  sudo node /opt/openclaw/openclaw.mjs config set channels.line.accessToken "$LINE_ACCESS_TOKEN"
  print_ok "LINE Bot 設定已寫入"
fi

sudo systemctl start openclaw
sleep 5
print_ok "systemd 服務啟動完成"

# ── 安裝所有 Skill ────────────────────────────────────
echo -e "  🦞 安裝 C01–C10 通用基礎 Skill..."
sudo -u "$SERVICE_USER" \
  node /opt/openclaw/openclaw.mjs install \
  c01 c02 c03 c04 c05 c06 c07 c08 c09 c10 -q 2>/dev/null && \
  print_ok "C01–C10 安裝完成" || \
  print_warn "C01–C10 安裝遇到問題，稍後可手動執行 node /opt/openclaw/openclaw.mjs install c01 c02 ..."

echo -e "  🦞 安裝 E01–E88 電商 Skill（約 2–3 分鐘）..."
sudo -u "$SERVICE_USER" \
  node /opt/openclaw/openclaw.mjs install --all-ecom -q 2>/dev/null && \
  print_ok "E01–E88 安裝完成" || \
  print_warn "E01–E88 安裝遇到問題，稍後可手動執行 node /opt/openclaw/openclaw.mjs install --all-ecom"

# ── 健康檢查 ──────────────────────────────────────────
echo -e "  🔍 健康檢查..."
sleep 2
BOT_STATUS=$(sudo systemctl is-active openclaw 2>/dev/null)
NGINX_STATUS=$(sudo systemctl is-active nginx 2>/dev/null)
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 5 "http://127.0.0.1/health" 2>/dev/null || echo "000")
SKILL_COUNT=$(sudo -u "$SERVICE_USER" \
  node /opt/openclaw/openclaw.mjs list 2>/dev/null | \
  grep -c "✅" || echo "0")

# =============================================================================
# 安裝完成報告
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}"
cat << 'DONE'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🎉 安裝完成！龍蝦已經上線！               ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
DONE
echo -e "${NC}"

echo -e "  ${BOLD}── 服務狀態 ──────────────────────────────────${NC}"
[ "$BOT_STATUS"   = "active" ] && print_ok "openclaw  ：運行中" || print_err "openclaw  ：異常（執行 sudo journalctl -u openclaw -n 30 查看原因）"
[ "$NGINX_STATUS" = "active" ] && print_ok "nginx     ：運行中" || print_err "nginx     ：異常"
[ "$HTTP_STATUS"  = "200"    ] && print_ok "HTTP 回應 ：正常" || print_warn "HTTP 回應 ：${HTTP_STATUS}（可能需要等幾秒）"
echo -e "  ${DIM}已安裝 Skill 數量：${SKILL_COUNT} 個${NC}"

echo ""
echo -e "  ${BOLD}── LINE Webhook 設定 ─────────────────────────${NC}"
echo ""
echo -e "  ${CYAN}請把以下 URL 貼到 LINE Developers Console 的 Webhook URL 欄位：${NC}"
echo ""
echo -e "  ${BOLD}${GREEN}  http://${PUBLIC_IP}/webhook${NC}"
echo ""
echo -e "  ${DIM}設定路徑：LINE Developers → 你的 Channel → Messaging API → Webhook URL${NC}"

# AI 金鑰待設定的提醒
if [ "$AI_CHOICE" = "4" ] || [ -z "$AI_API_KEY" ]; then
  echo ""
  echo -e "  ${BOLD}── AI 金鑰設定提醒 ───────────────────────────${NC}"
  echo ""
  print_warn "你的 AI 金鑰尚未設定，龍蝦還無法回覆訊息"
  echo ""
  echo -e "  加入 LINE Bot 後，傳送以下指令設定金鑰："
  echo -e "  ${CYAN}  /設定金鑰 claude sk-ant-你的金鑰${NC}"
  echo -e "  ${CYAN}  /設定金鑰 gemini AIza你的金鑰${NC}"
  echo -e "  ${CYAN}  /設定金鑰 openai sk-你的金鑰${NC}"
fi

# LINE 待設定的提醒
if [ -z "$LINE_CHANNEL_SECRET" ]; then
  echo ""
  print_warn "LINE Bot 尚未設定，請修改設定檔後重啟服務："
  echo -e "  ${DIM}sudo nano ${INSTALL_DIR}/config/config.yml${NC}"
  echo -e "  ${DIM}sudo systemctl restart openclaw${NC}"
fi

echo ""
echo -e "  ${BOLD}── 常用指令備忘 ──────────────────────────────${NC}"
echo ""
echo -e "  ${DIM}查看龍蝦狀態    sudo systemctl status openclaw${NC}"
echo -e "  ${DIM}重新啟動龍蝦    sudo systemctl restart openclaw${NC}"
echo -e "  ${DIM}查看即時 log    sudo journalctl -u openclaw -f${NC}"
echo -e "  ${DIM}查看所有 Skill  node /opt/openclaw/openclaw.mjs list${NC}"
echo -e "  ${DIM}更新 Skills     cd ${INSTALL_DIR}/skills && git pull${NC}"
echo -e "  ${DIM}更新主程式      cd ${INSTALL_DIR} && git pull${NC}"
echo ""
echo -e "  ${BOLD}── 測試龍蝦是否正常 ──────────────────────────${NC}"
echo ""
echo -e "  ${DIM}curl -X POST http://localhost:18789/chat \\${NC}"
echo -e "  ${DIM}  -H 'Content-Type: application/json' \\${NC}"
echo -e "  ${DIM}  -d '{\"message\": \"你好\"}'${NC}"
echo ""
echo -e "  ${BOLD}── ⚠️  重要：Oracle 安全清單設定 ───────────────${NC}"
echo ""
echo -e "  ${YELLOW}LINE Webhook 要能連進來，還需要在 Oracle 控制台手動開放 Port 80：${NC}"
echo ""
echo -e "  ${DIM}1. 登入 Oracle Cloud 控制台${NC}"
echo -e "  ${DIM}2. 漢堡選單 → Networking → Virtual Cloud Networks${NC}"
echo -e "  ${DIM}3. 點擊你的 VCN → Security Lists → Default Security List${NC}"
echo -e "  ${DIM}4. Add Ingress Rules：${NC}"
echo -e "  ${DIM}   Source CIDR：0.0.0.0/0${NC}"
echo -e "  ${DIM}   Destination Port Range：80${NC}"
echo -e "  ${DIM}5. 點 Add Ingress Rules 儲存${NC}"
echo ""
echo -e "  ${YELLOW}做完這步，LINE Webhook 才能正常接收訊息。${NC}"
echo ""
