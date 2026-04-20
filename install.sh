#!/bin/bash
# ============================================================
# AICLAW x OpenClaw — 龍蝦一鍵安裝腳本
# 適用：Oracle Cloud Ubuntu 22.04 / 24.04 (ARM / AMD)
# 版本：1.0.0
# ============================================================

set -e

# 顏色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}▶ $1${NC}"; }
print_ok()   { echo -e "${GREEN}✓ $1${NC}"; }
print_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_err()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

echo ""
echo -e "${GREEN}🦞 AICLAW x OpenClaw 龍蝦安裝程式${NC}"
echo "============================================"
echo ""

# ── 1. 檢查作業系統 ──────────────────────────────────────────
print_step "檢查系統環境..."
if [[ "$(uname)" != "Linux" ]]; then
  print_err "此腳本僅支援 Linux (Oracle Cloud Ubuntu)"
fi
print_ok "Linux 環境確認"

# ── 2. 更新系統套件 ──────────────────────────────────────────
print_step "更新系統套件..."
sudo apt-get update -q
sudo apt-get install -y -q curl wget git unzip build-essential
print_ok "系統套件更新完成"

# ── 3. 安裝 Node.js 20 LTS ───────────────────────────────────
print_step "安裝 Node.js 20 LTS..."
if command -v node &> /dev/null; then
  NODE_VER=$(node -v)
  print_warn "Node.js 已安裝：$NODE_VER"
else
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
  print_ok "Node.js $(node -v) 安裝完成"
fi

# ── 4. 安裝 OpenClaw ─────────────────────────────────────────
print_step "安裝 OpenClaw..."
if command -v openclaw &> /dev/null; then
  print_warn "OpenClaw 已安裝，執行更新..."
  sudo npm update -g openclaw
else
  sudo npm install -g openclaw
fi
print_ok "OpenClaw $(openclaw --version 2>/dev/null || echo '已安裝') 完成"

# ── 5. 建立 skills 目錄 ──────────────────────────────────────
print_step "建立技能目錄..."
SKILLS_DIR="$HOME/.openclaw/skills"
mkdir -p "$SKILLS_DIR"
print_ok "技能目錄：$SKILLS_DIR"

# ── 6. 下載 AICLAW Skills ────────────────────────────────────
print_step "下載 AICLAW 電商技能包..."

# ★ 將此處換成你的 Google Drive 直接下載連結
# 格式：https://drive.google.com/uc?export=download&id=<FILE_ID>
SKILLS_ZIP_URL="__GOOGLE_DRIVE_ZIP_URL__"

SKILLS_DIR="$HOME/.openclaw/skills"
mkdir -p "$SKILLS_DIR"
TMP_ZIP="/tmp/aiclaw-skills.zip"

if [[ "$SKILLS_ZIP_URL" == "__GOOGLE_DRIVE_ZIP_URL__" ]]; then
  print_warn "技能包 URL 尚未設定，跳過自動下載"
  print_warn "請把 aiclaw-skills.zip 手動上傳並更新此腳本的 SKILLS_ZIP_URL"
else
  print_step "下載技能包（來自 Google Drive）..."
  curl -fsSL -o "$TMP_ZIP" "$SKILLS_ZIP_URL"

  print_step "解壓縮技能包..."
  unzip -q -o "$TMP_ZIP" -d "$SKILLS_DIR"
  rm -f "$TMP_ZIP"
  print_ok "技能包安裝完成：$(ls "$SKILLS_DIR" | wc -l) 個技能"
fi

# ── 7. 安裝 MEMORY.md 範本 ──────────────────────────────────
print_step "安裝記憶範本..."
WORKSPACE_DIR="$HOME/.openclaw/workspace"
MEMORY_FILE="$WORKSPACE_DIR/MEMORY.md"
mkdir -p "$WORKSPACE_DIR"

if [[ -f "$MEMORY_FILE" ]]; then
  print_warn "MEMORY.md 已存在，略過（不覆蓋）"
else
  if [[ "$SKILLS_ZIP_URL" != "__GOOGLE_DRIVE_ZIP_URL__" ]]; then
    curl -fsSL "${SKILLS_ZIP_URL/aiclaw-skills.zip/MEMORY.md}" -o "$MEMORY_FILE" 2>/dev/null \
      && print_ok "記憶範本已安裝：$MEMORY_FILE" \
      || cp "$(dirname "$0")/MEMORY.md" "$MEMORY_FILE" 2>/dev/null \
      && print_ok "記憶範本已安裝（本地）：$MEMORY_FILE" \
      || print_warn "MEMORY.md 安裝失敗，請課堂上手動建立"
  else
    print_warn "MEMORY.md 請在課堂上手動填入"
  fi
fi

# ── 8. 設定 systemd 服務（開機自動啟動）──────────────────────
print_step "設定系統服務（開機自動啟動）..."

OPENCLAW_PATH=$(which openclaw)

sudo tee /etc/systemd/system/openclaw.service > /dev/null <<EOF
[Unit]
Description=OpenClaw AI Assistant
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME
ExecStart=$OPENCLAW_PATH start
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=HOME=$HOME

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable openclaw
print_ok "系統服務設定完成（將在開機時自動啟動）"

# ── 9. 開放防火牆 port（如需要）─────────────────────────────
print_step "檢查防火牆設定..."
if command -v ufw &> /dev/null; then
  sudo ufw allow ssh
  print_ok "SSH port 已確認開放"
fi

# ── 9. 完成提示 ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}🦞 龍蝦安裝完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "下一步："
echo "  1. 填寫記憶範本（重要！）："
echo -e "     ${YELLOW}nano ~/.openclaw/workspace/MEMORY.md${NC}"
echo "     → 填入你的店名、平台、競品等基本資料"
echo ""
echo "  2. 執行初始化設定："
echo -e "     ${YELLOW}openclaw onboard${NC}"
echo ""
echo "  3. 準備好以下資訊（至少一個頻道）："
echo "     • Claude/OpenAI API Key"
echo "     • [Telegram] Bot Token（從 @BotFather 取得）"
echo "     • [LINE] Channel Access Token + Channel Secret"
echo "     • 兩個都填也可以，龍蝦會同時在兩個頻道上線"
echo ""
echo "  4. 完成設定後啟動龍蝦："
echo -e "     ${YELLOW}sudo systemctl start openclaw${NC}"
echo ""
echo "  5. 查看龍蝦狀態："
echo -e "     ${YELLOW}sudo systemctl status openclaw${NC}"
echo ""
echo -e "課程資源：https://aiclaw.notion.site（課堂提供）"
echo ""
