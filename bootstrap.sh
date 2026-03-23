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
SKILLS_TOKEN=""   # 安裝過程中由學員輸入
SKILLS_REPO=""    # 取得 PAT 後動態組合

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
# 第零步：輸入 Skills GitHub PAT
# =============================================================================
print_step "第零步：輸入課程 Skills 存取金鑰"

echo -e "  安裝 Skills 需要你的 GitHub PAT（課程金鑰）"
echo -e "  ${DIM}Joanna 會在課程群組提供你專屬的 PAT${NC}"
echo -e "  ${DIM}格式像：github_pat_11Axxxxxxxx...${NC}"
echo ""

while true; do
  ask_secret "請貼上你的 GitHub PAT" SKILLS_TOKEN
  if [[ "$SKILLS_TOKEN" == github_pat_* ]]; then
    print_ok "PAT 格式正確"
    break
  elif [[ -n "$SKILLS_TOKEN" ]]; then
    print_warn "格式不對，PAT 應以 github_pat_ 開頭，請重新貼上"
  else
    print_warn "PAT 不能為空，請重新輸入"
  fi
done

# 組合 SKILLS_REPO
SKILLS_REPO="https://${SKILLS_TOKEN}@github.com/Joanna8521/openclaw_ecom.git"

# 先存到環境變數檔，install_skill.sh 之後也能讀到
sudo mkdir -p /etc
sudo touch /etc/openclaw.env
sudo chmod 600 /etc/openclaw.env
# 移除舊的（如果重裝）
sudo sed -i '/^GITHUB_PAT=/d' /etc/openclaw.env 2>/dev/null || true
echo "GITHUB_PAT=${SKILLS_TOKEN}" | sudo tee -a /etc/openclaw.env > /dev/null
print_ok "PAT 已安全儲存到 /etc/openclaw.env"

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
  print_warn "跳過 Google 設定，稍後可執行 python3 openclaw setup google 來設定"
fi

# =============================================================================
# 確認資訊
# =============================================================================
print_step "確認設定資訊"

echo -e "  ${BOLD}安裝目錄：${NC}${INSTALL_DIR}"
echo ""
echo -e "  ${BOLD}Skills PAT：${NC}✅ 已輸入（儲存於 /etc/openclaw.env）"
echo ""
echo -e "  ${BOLD}AI 引擎：${NC}"
case "$AI_CHOICE" in
  1) echo -e "    Claude  $([ -n "$AI_API_KEY" ] && echo "✅ Key 已設定" || echo "⚠️  待設定")" ;;
  2) echo -e "    Gemini  $([ -n "$AI_API_KEY" ] && echo "✅ Key 已設定" || echo "⚠️  待設定")" ;;
  3) echo -e "    OpenAI  $([ -n "$AI_API_KEY" ] && echo "✅ Key 已設定" || echo "⚠️  待設定")" ;;
  4) echo -e "    ⚠️  待設定" ;;
esac
echo ""
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
sudo apt-get install -y -qq \
  python3 python3-pip python3-venv \
  nodejs npm \
  git curl wget jq \
  nginx certbot \
  cron build-essential 2>/dev/null
print_ok "系統套件安裝完成"

# ── Python 3.11 ───────────────────────────────────────
echo -e "  🐍 確認 Python 3.11..."
if ! python3 --version 2>/dev/null | grep -q "3.11"; then
  sudo apt-get install -y -qq software-properties-common
  sudo add-apt-repository ppa:deadsnakes/ppa -y
  sudo apt-get update -qq
  sudo apt-get install -y -qq python3.11 python3.11-venv python3.11-dev
  sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
fi
print_ok "Python $(python3 --version) 就緒"

# ── 服務使用者 ────────────────────────────────────────
if ! id "$SERVICE_USER" &>/dev/null; then
  sudo useradd -r -s /bin/bash -m -d "$INSTALL_DIR" "$SERVICE_USER"
  print_ok "建立服務使用者：${SERVICE_USER}"
fi

# ── 下載 OpenClaw 主程式 ──────────────────────────────
echo -e "  📥 下載 OpenClaw 主程式..."
sudo mkdir -p "$INSTALL_DIR"
if [ -d "$INSTALL_DIR/.git" ]; then
  sudo -u "$SERVICE_USER" git -C "$INSTALL_DIR" pull -q
  print_ok "OpenClaw 主程式更新完成"
else
  sudo git clone --quiet "$OPENCLAW_REPO" "$INSTALL_DIR"
  sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
  print_ok "OpenClaw 主程式下載完成"
fi

# ── 下載 Skills ───────────────────────────────────────
echo -e "  📥 下載 98 個 Skill..."
SKILLS_DIR="$INSTALL_DIR/skills"
sudo mkdir -p "$SKILLS_DIR"
if [ -d "$SKILLS_DIR/.git" ]; then
  sudo -u "$SERVICE_USER" git -C "$SKILLS_DIR" pull -q
  print_ok "Skills 更新完成"
else
  sudo git clone --quiet "$SKILLS_REPO" "$SKILLS_DIR"
  sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$SKILLS_DIR"
  print_ok "98 個 Skill 下載完成"
fi

# ── Python 虛擬環境 ───────────────────────────────────
echo -e "  🐍 建立 Python 虛擬環境..."
sudo -u "$SERVICE_USER" python3 -m venv "$INSTALL_DIR/venv"
sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install --upgrade pip -q
sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install \
  -r "$INSTALL_DIR/requirements.txt" -q
print_ok "Python 套件安裝完成"

# ── 設定檔 ────────────────────────────────────────────
echo -e "  🔑 寫入設定檔..."
sudo mkdir -p "$INSTALL_DIR/config"

sudo tee "$INSTALL_DIR/config/config.yml" > /dev/null << EOF
# OpenClaw 設定檔
# 修改後執行 sudo systemctl restart openclaw 生效

# ── AI 引擎設定 ──────────────────────────────────────
ai:
  provider: "${AI_PROVIDER}"     # claude / gemini / openai / pending
  claude_api_key: "${AI_PROVIDER == "claude" && echo "$AI_API_KEY" || echo ""}"
  gemini_api_key: "${AI_PROVIDER == "gemini" && echo "$AI_API_KEY" || echo ""}"
  openai_api_key: "${AI_PROVIDER == "openai" && echo "$AI_API_KEY" || echo ""}"

# ── LINE Bot 設定 ────────────────────────────────────
line:
  channel_secret: "${LINE_CHANNEL_SECRET}"
  access_token: "${LINE_ACCESS_TOKEN}"

# ── Google 服務設定 ──────────────────────────────────
google:
  credentials_path: "${GOOGLE_CREDENTIALS_PATH}"

# ── Skills 路徑 ──────────────────────────────────────
skills:
  path: "${INSTALL_DIR}/skills"
  enabled: true

# ── 伺服器設定 ───────────────────────────────────────
server:
  host: "0.0.0.0"
  port: 5000
  workers: 2
EOF

# 修正 YAML 裡 bash 條件判斷語法（直接用已設好的變數）
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
  port: 5000
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
        proxy_pass http://127.0.0.1:5000/webhook;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
    }

    # API
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 60s;
    }

    # 健康檢查
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
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
User=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/python main.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable openclaw -q
sudo systemctl start openclaw
sleep 3
print_ok "systemd 服務啟動完成"

# ── 安裝所有 Skill ────────────────────────────────────
echo -e "  🦞 安裝 C01–C10 通用基礎 Skill..."
sudo -u "$SERVICE_USER" \
  "$INSTALL_DIR/venv/bin/python3" openclaw install \
  c01 c02 c03 c04 c05 c06 c07 c08 c09 c10 -q 2>/dev/null && \
  print_ok "C01–C10 安裝完成" || \
  print_warn "C01–C10 安裝遇到問題，稍後可手動執行 python3 openclaw install c01 c02 ..."

echo -e "  🦞 安裝 E01–E88 電商 Skill（約 2–3 分鐘）..."
sudo -u "$SERVICE_USER" \
  "$INSTALL_DIR/venv/bin/python3" openclaw install --all-ecom -q 2>/dev/null && \
  print_ok "E01–E88 安裝完成" || \
  print_warn "E01–E88 安裝遇到問題，稍後可手動執行 python3 openclaw install --all-ecom"

# ── 健康檢查 ──────────────────────────────────────────
echo -e "  🔍 健康檢查..."
sleep 2
BOT_STATUS=$(sudo systemctl is-active openclaw 2>/dev/null)
NGINX_STATUS=$(sudo systemctl is-active nginx 2>/dev/null)
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 5 "http://127.0.0.1/health" 2>/dev/null || echo "000")
SKILL_COUNT=$(sudo -u "$SERVICE_USER" \
  "$INSTALL_DIR/venv/bin/python3" openclaw list 2>/dev/null | \
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
echo -e "  ${DIM}查看所有 Skill  python3 openclaw list${NC}"
echo -e "  ${DIM}更新 Skills     cd ${INSTALL_DIR}/skills && git pull${NC}"
echo -e "  ${DIM}更新主程式      cd ${INSTALL_DIR} && git pull${NC}"
echo ""
echo -e "  ${BOLD}── 測試龍蝦是否正常 ──────────────────────────${NC}"
echo ""
echo -e "  ${DIM}curl -X POST http://localhost:5000/chat \\${NC}"
echo -e "  ${DIM}  -H 'Content-Type: application/json' \\${NC}"
echo -e "  ${DIM}  -d '{\"message\": \"你好\"}'${NC}"
echo ""
