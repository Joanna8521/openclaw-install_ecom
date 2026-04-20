#!/bin/bash
# =============================================================================
#  🦞  OpenClaw Bootstrap 安裝腳本
#      電商+行銷+SEO 班 × OpenClaw_ecom 課程
#
#  ⚠️  不可用 curl | bash 執行！請先下載再跑：
#    curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/bootstrap.sh \
#      -o bootstrap.sh && chmod +x bootstrap.sh && sudo ./bootstrap.sh
#
#  自動完成：
#    1. 系統套件更新 + Node.js v22 安裝
#    2. 從 GitHub 安裝 OpenClaw 主程式（pnpm build）
#    3. 安裝電商班 Skills（Joanna8521/openclaw_ecom，含 D01）
#    4. 設定 Nginx 反向代理（Port 80）
#    5. 設定 systemd 服務（開機自動啟動）
#    6. 互動式設定 AI 引擎 + LINE（主）+ Telegram（可選）
#    7. Discord 若需要請安裝後再跑 setup_discord.sh
#
#  已驗證環境：Ubuntu 22.04 ARM（Oracle VM.Standard.A1.Flex）
#  需要 Node.js v22+（腳本自動安裝）
# =============================================================================
set -euo pipefail

# ── 顏色 ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

print_ok()   { echo -e "  ${GREEN}✅ ${RESET} $1"; }
print_info() { echo -e "  ${CYAN}⚙️ ${RESET}  $1"; }
print_warn() { echo -e "  ${YELLOW}⚠️ ${RESET}  $1"; }
print_err()  { echo -e "  ${RED}❌${RESET}  $1"; }
section()    { echo -e "\n${BLUE}════════════════════════════════════════════${RESET}"; echo -e "  ${BOLD}$1${RESET}"; echo -e "${BLUE}════════════════════════════════════════════${RESET}"; }

# ── 必須是 root ──────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  print_err "請用 sudo 執行：sudo bash bootstrap.sh"
  exit 1
fi

# ── 變數 ────────────────────────────────────────────────────────────────────
INSTALL_DIR="/opt/openclaw"
SKILLS_DIR="/root/.openclaw/skills"
WORKSPACE_DIR="/root/.openclaw/workspace"
OPENCLAW_REPO="https://github.com/openclaw/openclaw.git"
SKILLS_REPO_OWNER="Joanna8521"
SKILLS_REPO_NAME="openclaw_ecom"
SERVICE_FILE="/etc/systemd/system/openclaw.service"
NGINX_CONF="/etc/nginx/sites-available/openclaw"

# ── Banner ──────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🦞  OpenClaw 安裝腳本                 ║
  ║         電商+行銷+SEO 班 × openclaw_ecom  ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER
echo -e "${RESET}"

# ── STEP 1：收集設定資訊 ──────────────────────────────────────────────────────
section "STEP 1｜設定資訊輸入"

echo ""
echo "  請依序輸入以下設定。輸入密碼 / Key 時畫面不顯示字，這是正常安全機制。"
echo ""
echo "  頻道優先順序：LINE（主）> Telegram（可選）> Discord（安裝後另設）"
echo ""

# ── AI 引擎選擇 ──────────────────────────────────────────────────────────────
echo "  選擇 AI 引擎："
echo "  1) Claude（Anthropic）  — 推薦，繁中支援最好"
echo "  2) Gemini（Google）     — 免費額度較多"
echo ""
read -r -p "  請輸入選項 [1/2，預設 1]：" AI_CHOICE
echo ""

case "${AI_CHOICE:-1}" in
  2)
    AI_PROVIDER="google"
    AI_MODEL="google/gemini-2.5-pro"
    AI_ENV_VAR="GOOGLE_API_KEY"
    AI_LABEL="Gemini API Key（aistudio.google.com 取得）"
    ;;
  *)
    AI_PROVIDER="anthropic"
    AI_MODEL="anthropic/claude-sonnet-4-6"
    AI_ENV_VAR="ANTHROPIC_API_KEY"
    AI_LABEL="Claude API Key（console.anthropic.com 取得）"
    ;;
esac

read -r -s -p "  請貼上 ${AI_LABEL}：" AI_KEY
echo ""
if [ -z "$AI_KEY" ]; then
  print_warn "未輸入 API Key，稍後可手動設定"
fi

# ── LINE Bot（主要頻道） ──────────────────────────────────────────────────────
echo ""
echo "  ── LINE Bot（主要通知頻道）────────────────────"
echo "  取得方式：developers.line.biz → 你的 Channel → Messaging API"
echo "  需要：Channel Secret + Channel Access Token"
echo ""
read -r -p "  現在設定 LINE 嗎？[Y/n]：" SETUP_LINE
if [[ "${SETUP_LINE,,}" != "n" ]]; then
  read -r -s -p "  LINE Channel Secret：" LINE_SECRET
  echo ""
  read -r -s -p "  LINE Channel Access Token：" LINE_TOKEN
  echo ""
  if [ -z "$LINE_SECRET" ] || [ -z "$LINE_TOKEN" ]; then
    print_warn "LINE 資訊不完整，將略過 LINE 設定"
    LINE_SECRET=""
    LINE_TOKEN=""
  fi
else
  LINE_SECRET=""
  LINE_TOKEN=""
  print_warn "略過 LINE，安裝後可用以下指令補設定："
  print_warn "  sudo node $INSTALL_DIR/openclaw.mjs config set channels.line.channelSecret <secret>"
  print_warn "  sudo node $INSTALL_DIR/openclaw.mjs config set channels.line.accessToken  <token>"
fi

# ── Telegram Bot Token（可選） ────────────────────────────────────────────────
echo ""
echo "  ── Telegram Bot（可選）────────────────────────"
echo "  取得方式：Telegram 搜尋 @BotFather → /newbot → 取得 Token"
echo ""
read -r -p "  要設定 Telegram Bot 嗎？[y/N]：" SETUP_TG
if [[ "${SETUP_TG,,}" == "y" ]]; then
  read -r -s -p "  請貼上 Telegram Bot Token：" TG_TOKEN
  echo ""
else
  TG_TOKEN=""
fi

# ── Discord 提示（不在此設） ─────────────────────────────────────────────────
echo ""
echo "  ── Discord（安裝後另設）──────────────────────"
echo "  如需 Discord，本腳本跑完後執行："
echo -e "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/${SKILLS_REPO_OWNER}/openclaw-install_ecom/main/setup_discord.sh \\${RESET}"
echo -e "  ${CYAN}  -o setup_discord.sh && chmod +x setup_discord.sh && sudo ./setup_discord.sh${RESET}"
echo ""

# ── Skills PAT ────────────────────────────────────────────────────────────────
echo ""
echo "  ── 課程技能庫存取碼 ───────────────────────────"
PAT_FILE="/root/.openclaw/skills_pat"
mkdir -p /root/.openclaw
if [ -f "$PAT_FILE" ]; then
  SKILLS_PAT=$(cat "$PAT_FILE")
  print_ok "課程存取碼已從設定檔讀取"
else
  read -r -s -p "  請貼上課程存取碼（github_pat_...）：" SKILLS_PAT
  echo ""
  if [ -n "$SKILLS_PAT" ]; then
    echo -n "$SKILLS_PAT" > "$PAT_FILE"
    chmod 600 "$PAT_FILE"
  fi
fi

# ── 確認資訊 ─────────────────────────────────────────────────────────────────
echo ""
echo "  ── 確認設定 ─────────────────────────────────────"
echo "  AI 引擎：${AI_PROVIDER} / ${AI_MODEL}"
[ -n "$AI_KEY" ]     && echo "  API Key：✅ 已設定" || echo "  API Key：⚠️  未設定"
[ -n "$LINE_TOKEN" ] && echo "  LINE：✅ 已設定（主）" || echo "  LINE：⚠️  未設定"
[ -n "$TG_TOKEN" ]   && echo "  Telegram：✅ 已設定" || echo "  Telegram：略過"
[ -n "$SKILLS_PAT" ] && echo "  Skills PAT：✅ 已設定" || echo "  Skills PAT：⚠️  未設定"
echo ""
read -r -p "  確認無誤？按 Enter 開始安裝（Ctrl+C 中止）..."

# ── STEP 2：系統更新 + 套件 ──────────────────────────────────────────────────
section "STEP 2｜系統更新與套件安裝"
print_info "更新 apt 套件清單..."
apt-get update -qq

print_info "安裝基礎套件..."
apt-get install -y -qq \
  git curl wget jq nginx cron build-essential \
  ca-certificates gnupg lsb-release unzip 2>/dev/null
print_ok "基礎套件安裝完成"

# ── STEP 3：Node.js v22 ──────────────────────────────────────────────────────
section "STEP 3｜Node.js v22 安裝"
NODE_VER=$(node --version 2>/dev/null || echo "none")
NODE_MAJOR=$(echo "$NODE_VER" | grep -oP '(?<=v)\d+' || echo "0")

if [ "${NODE_MAJOR:-0}" -lt 22 ]; then
  print_info "目前 Node.js $NODE_VER，升級到 v22..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 2>/dev/null
  apt-get install -y -qq nodejs
  print_ok "Node.js $(node --version) 安裝完成"
else
  print_ok "Node.js $NODE_VER 已符合需求（>= v22）"
fi

# ── STEP 4：OpenClaw 主程式 ──────────────────────────────────────────────────
section "STEP 4｜OpenClaw 主程式安裝"
if [ -d "$INSTALL_DIR/.git" ]; then
  print_info "OpenClaw 已存在，更新到最新版..."
  cd "$INSTALL_DIR" && git pull --quiet
else
  print_info "從 GitHub 下載 OpenClaw..."
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 --quiet "$OPENCLAW_REPO" "$INSTALL_DIR"
fi
print_ok "OpenClaw 主程式下載完成"

print_info "安裝 pnpm..."
npm install -g pnpm --quiet 2>/dev/null
print_ok "pnpm 安裝完成"

print_info "安裝套件依賴..."
cd "$INSTALL_DIR"
pnpm install --silent 2>/dev/null
print_ok "套件依賴安裝完成"

print_info "Build OpenClaw..."
pnpm run build --silent 2>/dev/null || true
print_ok "Build 完成"

# ── STEP 5：初始化 OpenClaw 設定 ─────────────────────────────────────────────
section "STEP 5｜初始化 OpenClaw 設定"

print_info "初始化設定檔..."
node "$INSTALL_DIR/openclaw.mjs" setup 2>/dev/null || true
node "$INSTALL_DIR/openclaw.mjs" config set gateway.mode local 2>/dev/null || true
node "$INSTALL_DIR/openclaw.mjs" config set gateway.port 18789 2>/dev/null || true

# Skills 目錄
node "$INSTALL_DIR/openclaw.mjs" config set skills.load.extraDirs '["/root/.openclaw/skills"]' 2>/dev/null || true

# Persona systemPrompt（讓所有 Skill 自動帶入學員店家背景與長期記憶）
PERSONA_PROMPT='你是電商賣家的 AI 龍蝦助理「小龍蝦」。每次對話開始前必讀 /root/.openclaw/workspace/MEMORY.md，這是學員的長期記憶檔案，記錄了店家資訊、溝通偏好、常用資源和工作規則；所有建議都要依照這份記憶客製化。記憶分工：「我的店」區塊由 d02-brand-manager 技能自動管理（學員說「新增品牌」「切換品牌」「品牌列表」「/brand」時呼叫），其他區塊由 c00-memory 技能管理（學員說「記得...」「忘記...」「更新我的...」「你記得什麼」「清空記憶」時呼叫）。兩個記憶技能都不要自己寫檔，一律派遣對應 skill 處理。如果「我的店」顯示「【尚未設定，請輸入 /brand new 建立品牌】」，引導學員執行 /d01 入學診斷或 /brand new 建立第一個品牌。基本原則：數據優先（有數字就給數字，不要只說「不錯」「還好」）；寄信、發推播、刪資料等重要操作執行前先給學員確認；競品降價超過 10% 或負評出現時主動提醒，不等定時報告。'
node "$INSTALL_DIR/openclaw.mjs" config set agents.defaults.systemPrompt "$PERSONA_PROMPT" 2>/dev/null || true

# ── AI 引擎設定（環境變數 + paste-token 雙保險）────────────────────────────
if [ -n "$AI_KEY" ]; then
  # 1. 寫入 /root/.openclaw/.env
  OPENCLAW_ENV_FILE="/root/.openclaw/.env"
  touch "$OPENCLAW_ENV_FILE"
  grep -v "^${AI_ENV_VAR}=" "$OPENCLAW_ENV_FILE" > "${OPENCLAW_ENV_FILE}.tmp" 2>/dev/null || true
  echo "${AI_ENV_VAR}=${AI_KEY}" >> "${OPENCLAW_ENV_FILE}.tmp"
  mv "${OPENCLAW_ENV_FILE}.tmp" "$OPENCLAW_ENV_FILE"
  chmod 600 "$OPENCLAW_ENV_FILE"

  # 2. 設定 model
  node "$INSTALL_DIR/openclaw.mjs" config set agents.defaults.model.primary "$AI_MODEL" 2>/dev/null || true

  # 3. Anthropic 額外跑 paste-token
  if [ "$AI_PROVIDER" = "anthropic" ]; then
    echo "$AI_KEY" | node "$INSTALL_DIR/openclaw.mjs" models auth paste-token \
      --provider anthropic 2>/dev/null || true
  fi

  print_ok "AI 引擎設定完成（${AI_PROVIDER} / ${AI_MODEL}）"
else
  print_warn "API Key 未設定，稍後手動執行："
  print_warn "  Anthropic: sudo node $INSTALL_DIR/openclaw.mjs models auth paste-token --provider anthropic"
  print_warn "  其他:      echo 'API_KEY_VAR=你的Key' >> /root/.openclaw/.env"
fi

# ── LINE 設定（主要頻道） ────────────────────────────────────────────────────
if [ -n "$LINE_TOKEN" ] && [ -n "$LINE_SECRET" ]; then
  node "$INSTALL_DIR/openclaw.mjs" config set channels.line.enabled true 2>/dev/null || true
  node "$INSTALL_DIR/openclaw.mjs" config set channels.line.channelSecret "$LINE_SECRET" 2>/dev/null || true
  node "$INSTALL_DIR/openclaw.mjs" config set channels.line.accessToken "$LINE_TOKEN" 2>/dev/null || true
  print_ok "LINE Bot 設定完成（主要頻道）"
fi

# ── Telegram 設定（可選） ────────────────────────────────────────────────────
if [ -n "$TG_TOKEN" ]; then
  node "$INSTALL_DIR/openclaw.mjs" config set channels.telegram.enabled true 2>/dev/null || true
  node "$INSTALL_DIR/openclaw.mjs" config set channels.telegram.botToken "$TG_TOKEN" 2>/dev/null || true
  node "$INSTALL_DIR/openclaw.mjs" config set channels.telegram.dmPolicy pairing 2>/dev/null || true
  print_ok "Telegram Bot Token 設定完成"
fi

print_ok "OpenClaw 設定初始化完成"

# ── STEP 6：安裝電商班 Skills ────────────────────────────────────────────────
section "STEP 6｜安裝電商班 Skills（C01–C10 + D01 + E01–E88）"
mkdir -p "$SKILLS_DIR"

if [ -z "$SKILLS_PAT" ]; then
  print_warn "未提供課程存取碼，跳過 Skills 安裝"
  print_warn "之後可手動執行：git clone https://<存取碼>@github.com/${SKILLS_REPO_OWNER}/${SKILLS_REPO_NAME}.git /tmp/skills_tmp && cp -r /tmp/skills_tmp/skills/* $SKILLS_DIR/"
else
  print_info "從 GitHub 下載電商班 Skills..."
  TMP_SKILLS="/tmp/openclaw_ecom_skills_install"
  rm -rf "$TMP_SKILLS"
  CLONE_URL="https://${SKILLS_PAT}@github.com/${SKILLS_REPO_OWNER}/${SKILLS_REPO_NAME}.git"

  if git clone --depth 1 --quiet "$CLONE_URL" "$TMP_SKILLS" 2>/dev/null; then
    if [ -d "$TMP_SKILLS/skills" ]; then
      cp -r "$TMP_SKILLS/skills/"* "$SKILLS_DIR/" 2>/dev/null || true

      # Subagents：若 repo 是扁平 subagents/ 結構，自動轉成 skill 資料夾
      # 例：subagents/SA01_copywriter.md → $SKILLS_DIR/sa01-copywriter/SKILL.md
      if [ -d "$TMP_SKILLS/subagents" ]; then
        print_info "偵測到 subagents/ 扁平檔案，轉換為 skill 結構..."
        SA_COUNT=0
        for sa_file in "$TMP_SKILLS/subagents/"*.md; do
          [ -f "$sa_file" ] || continue
          sa_base=$(basename "$sa_file" .md)
          sa_folder=$(echo "$sa_base" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
          mkdir -p "$SKILLS_DIR/$sa_folder"
          cp "$sa_file" "$SKILLS_DIR/$sa_folder/SKILL.md"
          SA_COUNT=$((SA_COUNT + 1))
        done
        print_ok "Subagents 轉換完成（${SA_COUNT} 隻）"
      fi

      SKILL_COUNT=$(find "$SKILLS_DIR" -name 'SKILL.md' | wc -l)
      print_ok "電商班 Skills 安裝完成（${SKILL_COUNT} 個技能）"
    else
      print_warn "Skills 目錄結構不符預期，請確認 repo 內有 skills/ 資料夾"
    fi
    rm -rf "$TMP_SKILLS"
  else
    print_err "存取碼錯誤或 repo 不存在，Skills 安裝失敗"
    print_warn "請確認存取碼後重新執行此腳本"
  fi
fi

# 建立 MEMORY.md 長期記憶檔案（龍蝦每次對話會讀這個檔）
mkdir -p "$WORKSPACE_DIR"
if [ ! -f "$WORKSPACE_DIR/MEMORY.md" ]; then
  cat > "$WORKSPACE_DIR/MEMORY.md" << 'MEMORY_EOF'
# 龍蝦記憶檔案
# 路徑：~/.openclaw/workspace/MEMORY.md
# 說明：這是龍蝦的長期記憶，每次對話都會讀取這些資訊
#
# ⚠️ 「我的店」區塊由 D02（/brand use）自動管理，請勿手動修改格式
#     其他區塊可以自由編輯

---

## 基本資料

- 姓名/稱呼：【填入你希望龍蝦怎麼稱呼你】
- 時區：Asia/Taipei（UTC+8）
- 主要工作：電商賣家

## 我的店

- 店名：【尚未設定，請輸入 /brand new 建立品牌】
- 品牌代稱：
- 主要銷售平台：
- 主要商品類別：
- 價位帶：
- 目標客群：
- 品牌語氣：
- 核心賣點（USP）：
- 禁用詞：
- 主要競品：
- 旺季：
- 客服時段：
- 退換貨政策：
- 品牌備註：

## 溝通偏好

- 語言：繁體中文
- 回答風格：簡短直接，不要廢話，重點先說
- 數字優先：有數據就給數據，不要只說「不錯」「還好」
- 確認機制：寄信、刪資料、寄出訊息等重要操作，執行前一定先給我確認

## 每日任務設定

- 每日報告時間：早上 08:00
- 推送頻道：【Telegram / LINE / 兩個都要，填你用的】
- 報告內容：營收快報、競品異動、待處理負評

## 常用 Google 資源

- 競品監控試算表：【填入 Google Sheets URL】
- 每日報告試算表：【填入 Google Sheets URL】
- 素材資料夾：【填入 Google Drive 資料夾 URL】

## 工作規則

- 推播廣告文案前先給我看，確認後才發
- 分析數據時附上「建議下一步行動」，不要只列數字
- 發現競品降價超過 10%，立刻通知我，不用等定時報告
- 負評出現後 1 小時內提醒我，附上建議回覆草稿

## 不需要記的事

- 每次對話的閒聊內容
- 已解決的一次性問題
- 過期的促銷活動資訊
MEMORY_EOF
  chmod 600 "$WORKSPACE_DIR/MEMORY.md"
  print_ok "MEMORY.md 長期記憶檔建立完成"
fi

# 建立 memory_changelog.md（c00-memory 技能每次修改都會在這裡附一行）
if [ ! -f "$WORKSPACE_DIR/memory_changelog.md" ]; then
  cat > "$WORKSPACE_DIR/memory_changelog.md" << 'CHANGELOG_EOF'
# 記憶變更紀錄
# 每次 c00-memory 技能修改 MEMORY.md 都會在此附一行

CHANGELOG_EOF
  chmod 600 "$WORKSPACE_DIR/memory_changelog.md"
fi

# 保留 persona.json（D01 入學診斷若產出結構化資料會寫到這裡，跟 MEMORY.md 並存）
if [ ! -f "$WORKSPACE_DIR/persona.json" ]; then
  cat > "$WORKSPACE_DIR/persona.json" << 'PERSONA_EOF'
{
  "_note": "D01 入學診斷自動填寫的結構化資料，MEMORY.md 是主記憶檔",
  "name": "",
  "shop_name": "",
  "platforms": [],
  "categories": [],
  "competitors": [],
  "target_audience": "",
  "daily_report_time": "08:00",
  "report_channels": [],
  "google_resources": {
    "competitor_sheet": "",
    "daily_report_sheet": "",
    "assets_folder": ""
  },
  "updated_at": ""
}
PERSONA_EOF
  print_ok "persona.json 模板建立完成"
fi

# ── STEP 7：Nginx 設定 ───────────────────────────────────────────────────────
section "STEP 7｜設定 Nginx 反向代理"
cat > "$NGINX_CONF" << 'NGINX'
server {
    listen 80;
    server_name _;

    location /line/webhook {
        proxy_pass http://127.0.0.1:18789/line/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
    }

    location /telegram/webhook {
        proxy_pass http://127.0.0.1:18789/telegram/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 60s;
    }

    location /discord/webhook {
        proxy_pass http://127.0.0.1:18789/discord/webhook;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 60s;
    }

    location /health {
        proxy_pass http://127.0.0.1:18789/health;
        proxy_http_version 1.1;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:18789/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/openclaw
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
nginx -t -q 2>/dev/null && systemctl reload nginx && print_ok "Nginx 設定完成" \
  || print_warn "Nginx 設定有問題，請執行 nginx -t 查看詳情"

# ── STEP 8：systemd 服務 ─────────────────────────────────────────────────────
section "STEP 8｜設定 systemd 自動啟動服務"
cat > "$SERVICE_FILE" << SYSTEMD
[Unit]
Description=OpenClaw AI 龍蝦助理（電商+行銷+SEO 班）
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node ${INSTALL_DIR}/openclaw.mjs gateway
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable openclaw --quiet
systemctl restart openclaw
sleep 5

if systemctl is-active --quiet openclaw; then
  print_ok "systemd 服務啟動完成"
else
  print_warn "服務啟動失敗，查看 log："
  journalctl -u openclaw -n 15 --no-pager
fi

# ── STEP 9：健康檢查 ─────────────────────────────────────────────────────────
section "STEP 9｜健康檢查"
PUBLIC_IP=$(curl -s --max-time 5 http://checkip.amazonaws.com 2>/dev/null \
  || curl -s --max-time 5 ifconfig.me 2>/dev/null \
  || echo "無法取得")
SKILL_COUNT_FINAL=$(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l)

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/health 2>/dev/null || echo "000")

print_ok "VM Public IP：$PUBLIC_IP"
print_ok "已安裝 Skill 數量：${SKILL_COUNT_FINAL}"
[ "$HTTP_STATUS" = "200" ] && print_ok "Gateway 回應正常（HTTP $HTTP_STATUS）" \
  || print_warn "Gateway 回應：$HTTP_STATUS（可能需要再等幾秒）"

# ── STEP 10：配對與 Webhook 設定引導 ─────────────────────────────────────────
section "STEP 10｜配對與 Webhook 設定"

# LINE Webhook URL（主要頻道）
if [ -n "$LINE_TOKEN" ]; then
  echo ""
  echo "  ── LINE Webhook 設定（主要頻道）─────────────"
  echo ""
  echo -e "  ${BOLD}Webhook URL：${GREEN}http://${PUBLIC_IP}/line/webhook${RESET}"
  echo ""
  echo "  填到 LINE Developers Console："
  echo "  Messaging API → Webhook URL → Verify"
  echo "  記得開啟「Use webhook」並關閉「Auto-reply messages」"
  echo ""
  read -r -p "  設定完成後按 Enter 繼續..."
fi

# Telegram 配對
if [ -n "$TG_TOKEN" ]; then
  echo ""
  echo "  ── Telegram 配對 ────────────────────────────"
  echo "  1. 打開 Telegram，搜尋你的 Bot（t.me/你的bot名稱）"
  echo "  2. 發送任意訊息（例如：你好）"
  echo "  3. Bot 會回覆 8 位配對碼，格式如：Y9L7C7RG"
  echo ""
  read -r -p "  請貼上配對碼（若暫不配對直接 Enter 跳過）：" PAIRING_CODE
  echo ""

  if [ -n "$PAIRING_CODE" ]; then
    node "$INSTALL_DIR/openclaw.mjs" pairing approve telegram "$PAIRING_CODE" 2>/dev/null \
      && print_ok "Telegram 配對成功！" \
      || print_warn "配對失敗，請確認配對碼是否正確"
  else
    print_warn "跳過 Telegram 配對，稍後手動執行："
    echo -e "  ${CYAN}sudo node $INSTALL_DIR/openclaw.mjs pairing approve telegram 配對碼${RESET}"
  fi
fi

# ── 完成 ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}════════════════════════════════════════════${RESET}"
echo -e "  🦞 OpenClaw 電商班 部署完成！"
echo -e "${BLUE}════════════════════════════════════════════${RESET}"
echo ""
echo "  下一步："
echo "  • 傳送 /d01 給 Bot → 開始入學診斷，建立你的店家 persona"
[ -n "$LINE_TOKEN" ]  && echo "  • LINE Webhook：http://${PUBLIC_IP}/line/webhook"
[ -z "$TG_TOKEN"   ] && echo "  • 需要 Telegram？隨時可以設定 channels.telegram.botToken 再重啟"
echo "  • 需要 Discord？執行 setup_discord.sh"
echo ""
echo "  已安裝 Skill 數量：${SKILL_COUNT_FINAL}"
echo ""
echo "  常用指令："
echo "  查看龍蝦狀態    sudo systemctl status openclaw"
echo "  重新啟動龍蝦    sudo systemctl restart openclaw"
echo "  查看即時 log    sudo journalctl -u openclaw -f"
echo ""
