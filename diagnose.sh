#!/bin/bash
# =============================================================================
#  🦞  OpenClaw 自助診斷腳本（電商+行銷+SEO 班）
#
#  裝完後跑一下確認一切正常。遇到問題時也可以先跑這隻，把輸出貼給老師。
#
#  執行方式：
#    sudo bash diagnose.sh
#
#  這隻腳本只讀資料、不改任何設定，安全可重複執行。
# =============================================================================

# ── 顏色 ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── 計數器 ──────────────────────────────────────────────────────────────────
PASS=0; WARN=0; FAIL=0
ISSUES=()

# ── 輔助函式 ────────────────────────────────────────────────────────────────
ok()   { echo -e "  ${GREEN}✅${RESET}  $1"; PASS=$((PASS+1)); }
warn() { echo -e "  ${YELLOW}⚠️ ${RESET}  $1"; WARN=$((WARN+1)); ISSUES+=("⚠️  $1"); }
fail() { echo -e "  ${RED}❌${RESET}  $1"; FAIL=$((FAIL+1)); ISSUES+=("❌  $1"); }
info() { echo -e "  ${DIM}▸${RESET}  $1"; }
section() {
  echo ""
  echo -e "${BLUE}────────────────────────────────────────────${RESET}"
  echo -e "  ${BOLD}$1${RESET}"
  echo -e "${BLUE}────────────────────────────────────────────${RESET}"
}

# ── 需要 root ───────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "  ${RED}❌  請用 sudo 執行：sudo bash diagnose.sh${RESET}"
  exit 1
fi

# ── 變數 ────────────────────────────────────────────────────────────────────
INSTALL_DIR="/opt/openclaw"
SKILLS_DIR="/root/.openclaw/skills"
WORKSPACE_DIR="/root/.openclaw/workspace"
ENV_FILE="/root/.openclaw/.env"
PAT_FILE="/root/.openclaw/skills_pat"
GATEWAY_PORT="18789"

# ── Banner ──────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🦞  OpenClaw 自助診斷                 ║
  ║         電商+行銷+SEO 班                  ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER
echo -e "${RESET}"
echo "  這隻腳本會檢查安裝狀況，不會修改任何設定。"
echo "  出問題時把結尾的摘要貼給老師，方便定位問題。"

# ═════════════════════════════════════════════════════════════════════════════
# 1. 系統環境
# ═════════════════════════════════════════════════════════════════════════════
section "1｜系統環境"

# Node.js
NODE_VER=$(node --version 2>/dev/null || echo "none")
NODE_MAJOR=$(echo "$NODE_VER" | grep -oP '(?<=v)\d+' || echo "0")
if [ "${NODE_MAJOR:-0}" -ge 22 ]; then
  ok "Node.js $NODE_VER（>= v22 ✓）"
elif [ "$NODE_VER" = "none" ]; then
  fail "Node.js 沒裝。重跑 bootstrap.sh"
else
  fail "Node.js $NODE_VER 版本太舊（要 v22+）。重跑 bootstrap.sh 會自動升級"
fi

# pnpm
if command -v pnpm >/dev/null 2>&1; then
  ok "pnpm $(pnpm --version 2>/dev/null) 已安裝"
else
  warn "pnpm 沒裝（bootstrap 應該會裝），OpenClaw 可能未完整 build"
fi

# OpenClaw 主程式
if [ -f "${INSTALL_DIR}/openclaw.mjs" ]; then
  ok "OpenClaw 主程式存在（${INSTALL_DIR}/openclaw.mjs）"
else
  fail "找不到 ${INSTALL_DIR}/openclaw.mjs，bootstrap.sh 沒跑完或 git clone 失敗"
fi

# 常用工具
for cmd in git curl jq nginx; do
  if command -v $cmd >/dev/null 2>&1; then
    info "$cmd ✓"
  else
    warn "$cmd 沒裝"
  fi
done

# ═════════════════════════════════════════════════════════════════════════════
# 2. OpenClaw 服務狀態
# ═════════════════════════════════════════════════════════════════════════════
section "2｜OpenClaw 服務"

if systemctl list-unit-files 2>/dev/null | grep -q '^openclaw\.service'; then
  ok "systemd 服務檔存在"

  if systemctl is-active --quiet openclaw; then
    ok "服務正在運行（active）"
  else
    fail "服務沒在跑。可用 'sudo systemctl start openclaw' 啟動"
  fi

  if systemctl is-enabled --quiet openclaw 2>/dev/null; then
    ok "開機自動啟動已啟用"
  else
    warn "沒設定開機自動啟動。執行 'sudo systemctl enable openclaw'"
  fi

  # 看最近 5 分鐘有沒有 error
  RECENT_ERRORS=$(journalctl -u openclaw --since "5 min ago" -p err --no-pager 2>/dev/null | grep -v "^--" | grep -c "." || echo 0)
  if [ "$RECENT_ERRORS" -eq 0 ]; then
    ok "最近 5 分鐘沒有 error 等級的日誌"
  else
    warn "最近 5 分鐘有 ${RECENT_ERRORS} 行 error 日誌（結尾會顯示最後幾行）"
  fi
else
  fail "systemd 服務檔不存在（/etc/systemd/system/openclaw.service）。bootstrap.sh 沒跑完"
fi

# Gateway 健康檢查
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  "http://localhost:${GATEWAY_PORT}/health" 2>/dev/null || echo "000")
case "$HTTP_STATUS" in
  200) ok "Gateway /health 回應 200（port ${GATEWAY_PORT}）" ;;
  000) fail "Gateway 連不上（port ${GATEWAY_PORT}）。服務沒起來或 port 被佔用" ;;
  *)   warn "Gateway 回應 HTTP ${HTTP_STATUS}（預期 200）" ;;
esac

# Port 佔用檢查
if ss -tlnp 2>/dev/null | grep -q ":${GATEWAY_PORT} "; then
  info "Port ${GATEWAY_PORT} 有程序在聽"
else
  if [ "$HTTP_STATUS" = "200" ]; then
    info "Port ${GATEWAY_PORT} 看起來沒在聽但 /health 回 200？（應該是 localhost 綁定）"
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# 3. Nginx 反向代理
# ═════════════════════════════════════════════════════════════════════════════
section "3｜Nginx 反向代理"

if systemctl is-active --quiet nginx; then
  ok "Nginx 服務正在運行"
else
  fail "Nginx 沒在跑。執行 'sudo systemctl start nginx'"
fi

if [ -L "/etc/nginx/sites-enabled/openclaw" ] || [ -f "/etc/nginx/sites-enabled/openclaw" ]; then
  ok "OpenClaw 的 Nginx 站台設定已啟用"
else
  fail "找不到 /etc/nginx/sites-enabled/openclaw，LINE webhook 會收不到訊息"
fi

if nginx -t >/dev/null 2>&1; then
  ok "Nginx 設定語法正確（nginx -t 通過）"
else
  fail "Nginx 設定語法錯誤。執行 'sudo nginx -t' 查看詳情"
fi

# Port 80 localhost 測試
HTTP80=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost/health" 2>/dev/null || echo "000")
case "$HTTP80" in
  200) ok "Nginx → Gateway 代理正常（port 80 /health 回 200）" ;;
  000) fail "Nginx port 80 連不上" ;;
  *)   warn "Nginx port 80 /health 回 HTTP ${HTTP80}" ;;
esac

# ufw 防火牆
if command -v ufw >/dev/null 2>&1; then
  if ufw status 2>/dev/null | grep -q "80/tcp.*ALLOW"; then
    ok "防火牆允許 Port 80（LINE webhook 可達）"
  elif ufw status 2>/dev/null | grep -q "Status: inactive"; then
    info "ufw 沒啟用（VM 防火牆交給雲端商管）"
  else
    warn "ufw 啟用但可能沒開 Port 80。執行 'sudo ufw allow 80/tcp'"
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# 4. Skills 目錄
# ═════════════════════════════════════════════════════════════════════════════
section "4｜Skills"

if [ -d "$SKILLS_DIR" ]; then
  ok "Skills 目錄存在（$SKILLS_DIR）"

  SKILL_COUNT=$(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l)
  if [ "$SKILL_COUNT" -ge 90 ]; then
    ok "已安裝 Skill 數量：${SKILL_COUNT}（電商班約 99 個含 D01）"
  elif [ "$SKILL_COUNT" -gt 0 ]; then
    warn "只有 ${SKILL_COUNT} 個 skill，可能沒裝全。檢查 PAT 是否正確"
  else
    fail "沒有任何 SKILL.md。PAT 錯或 Skills git clone 失敗"
  fi

  # D01 入學診斷
  if [ -f "$SKILLS_DIR/d01-ecom-init/SKILL.md" ]; then
    ok "D01 入學診斷存在"
  else
    warn "找不到 D01（d01-ecom-init）。學員傳 /d01 會沒反應"
    info "  補裝：sudo bash install_skill.sh d01-ecom-init"
  fi

  # always:true 違規檢查（只有 D01 可以用）
  ALWAYS_SKILLS=$(grep -rl '"always":true' "$SKILLS_DIR" 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {} 2>/dev/null | sort -u)
  if [ -z "$ALWAYS_SKILLS" ]; then
    warn "沒有任何 skill 設 always:true（D01 應該要）"
  else
    BAD_ALWAYS=$(echo "$ALWAYS_SKILLS" | grep -v "^d01" || true)
    if [ -z "$BAD_ALWAYS" ]; then
      ok "always:true 只有 D01 使用（符合架構規則）"
    else
      warn "這些 skill 誤設了 always:true（架構規則只准 D01 設）："
      echo "$BAD_ALWAYS" | while read s; do echo -e "      ${YELLOW}→${RESET} $s"; done
    fi
  fi

  # SKILL.md 格式快掃
  BAD_FM=$(find "$SKILLS_DIR" -name "SKILL.md" 2>/dev/null | while read f; do
    head -1 "$f" 2>/dev/null | grep -qx '\-\-\-' || echo "$f"
  done | wc -l)
  if [ "$BAD_FM" -eq 0 ]; then
    ok "所有 SKILL.md 都有 YAML frontmatter"
  else
    warn "有 ${BAD_FM} 個 SKILL.md 缺 frontmatter（開頭不是 ---）"
  fi

else
  fail "Skills 目錄不存在（$SKILLS_DIR）"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 5. OpenClaw 設定
# ═════════════════════════════════════════════════════════════════════════════
section "5｜OpenClaw 設定"

CONFIG_FILE="/root/.openclaw/config.json"
if [ -f "$CONFIG_FILE" ]; then
  ok "設定檔存在（$CONFIG_FILE）"

  # skills.load.extraDirs
  if grep -q "$SKILLS_DIR" "$CONFIG_FILE" 2>/dev/null; then
    ok "skills.load.extraDirs 有指向 $SKILLS_DIR"
  else
    fail "skills.load.extraDirs 沒設 $SKILLS_DIR。OpenClaw 不會載入 Skills"
    info "  修復：sudo node ${INSTALL_DIR}/openclaw.mjs config set skills.load.extraDirs '[\"$SKILLS_DIR\"]'"
  fi

  # AI model
  if grep -q '"primary"' "$CONFIG_FILE" 2>/dev/null; then
    MODEL=$(grep -oP '"primary":\s*"[^"]+"' "$CONFIG_FILE" | head -1 | cut -d'"' -f4)
    ok "AI 模型已設：${MODEL:-unknown}"
  else
    warn "AI 模型（agents.defaults.model.primary）沒設"
  fi

  # 頻道檢查
  for channel in line telegram discord; do
    if grep -qE "\"${channel}\"[^}]*\"enabled\"[[:space:]]*:[[:space:]]*true" "$CONFIG_FILE" 2>/dev/null; then
      ok "頻道 ${channel}: enabled"
    else
      info "頻道 ${channel}: 未啟用"
    fi
  done

else
  fail "設定檔不存在（$CONFIG_FILE）。bootstrap.sh 沒跑完"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 6. 金鑰與環境變數
# ═════════════════════════════════════════════════════════════════════════════
section "6｜金鑰與環境"

# .env 檔
if [ -f "$ENV_FILE" ]; then
  PERM=$(stat -c "%a" "$ENV_FILE" 2>/dev/null)
  if [ "$PERM" = "600" ]; then
    ok ".env 存在且權限 600（$ENV_FILE）"
  else
    warn ".env 存在但權限是 $PERM（應為 600）"
  fi

  # 列有設哪些 key（只列名稱，不顯示值）
  KEYS=$(grep -oE '^[A-Z_]+=' "$ENV_FILE" 2>/dev/null | tr -d '=' | paste -sd, -)
  if [ -n "$KEYS" ]; then
    info "已設定環境變數：${KEYS}"
  fi

  # 檢查至少一個 AI key
  if grep -qE '^(ANTHROPIC_API_KEY|GOOGLE_API_KEY|OPENAI_API_KEY)=' "$ENV_FILE" 2>/dev/null; then
    ok "至少有一把 AI API key"
  else
    fail ".env 裡沒有 AI API Key（龍蝦不會回話）"
  fi
else
  fail ".env 不存在（$ENV_FILE）"
fi

# PAT 檔
if [ -f "$PAT_FILE" ]; then
  PAT_PERM=$(stat -c "%a" "$PAT_FILE" 2>/dev/null)
  PAT_PREFIX=$(head -c 14 "$PAT_FILE" 2>/dev/null)
  if [[ "$PAT_PREFIX" == github_pat_* ]]; then
    ok "課程存取碼（PAT）格式正確、權限 $PAT_PERM"
  else
    warn "PAT 檔存在但前綴不是 github_pat_（格式可能有問題）"
  fi
else
  warn "沒有 PAT 檔（裝 Skills 時會需要重新輸入）"
fi

# persona.json
if [ -f "$WORKSPACE_DIR/persona.json" ]; then
  if grep -q '"shop_name":\s*""' "$WORKSPACE_DIR/persona.json" 2>/dev/null; then
    info "persona.json 是空白模板（學員還沒跑 /d01）"
  else
    ok "persona.json 已有內容（學員做過 /d01 入學診斷）"
  fi
else
  warn "persona.json 不存在。建議跑 bootstrap.sh 或手動建立"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 7. 對外連線
# ═════════════════════════════════════════════════════════════════════════════
section "7｜對外連線"

check_endpoint() {
  local name="$1"
  local url="$2"
  local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [ "$code" != "000" ]; then
    ok "$name 可連（HTTP $code）"
  else
    warn "$name 連不上（$url）"
  fi
}

check_endpoint "GitHub API" "https://api.github.com"
check_endpoint "Anthropic API" "https://api.anthropic.com"

# 只有啟用才測
if grep -qE '"telegram"[^}]*"enabled"[[:space:]]*:[[:space:]]*true' "$CONFIG_FILE" 2>/dev/null; then
  check_endpoint "Telegram API" "https://api.telegram.org"
fi
if grep -qE '"line"[^}]*"enabled"[[:space:]]*:[[:space:]]*true' "$CONFIG_FILE" 2>/dev/null; then
  check_endpoint "LINE API" "https://api.line.me"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 8. 網路資訊
# ═════════════════════════════════════════════════════════════════════════════
section "8｜網路資訊"

PUBLIC_IP=$(curl -s --max-time 5 http://checkip.amazonaws.com 2>/dev/null \
  || curl -s --max-time 5 ifconfig.me 2>/dev/null \
  || echo "無法取得")
info "VM Public IP：${PUBLIC_IP}"
info "LINE Webhook URL：http://${PUBLIC_IP}/line/webhook"
info "Telegram Webhook URL：http://${PUBLIC_IP}/telegram/webhook（通常用 pairing，不用設）"

# ═════════════════════════════════════════════════════════════════════════════
# 9. GA4 整合
# ═════════════════════════════════════════════════════════════════════════════
section "9｜GA4 整合"

GA4_TOKEN_FILE="/root/.openclaw/google_ga4_token.json"
if [ -f "$GA4_TOKEN_FILE" ]; then
  PERM=$(stat -c "%a" "$GA4_TOKEN_FILE" 2>/dev/null)
  if [ "$PERM" = "600" ]; then
    ok "GA4 OAuth token 存在且權限 600"
  else
    warn "GA4 token 權限是 $PERM（應為 600）"
  fi

  # Property ID
  PERSONA_PATH="$WORKSPACE_DIR/persona.json"
  if [ -f "$PERSONA_PATH" ]; then
    GA4_PID=$(grep -oP '"ga4_property_id"\s*:\s*"\K[^"]*' "$PERSONA_PATH" 2>/dev/null)
    if [ -n "$GA4_PID" ]; then
      if [[ "$GA4_PID" =~ ^[0-9]{9,12}$ ]]; then
        ok "GA4 Property ID: $GA4_PID（格式正確）"
      elif [[ "$GA4_PID" =~ ^G- ]]; then
        fail "Property ID 是 Measurement ID（$GA4_PID）——GA4 Data API 不收這個，要的是 9 位數字。請重跑 /ga4 連接"
      else
        warn "Property ID 格式異常：$GA4_PID"
      fi
    else
      warn "persona.json 缺 ga4_property_id 欄位。請跑 /ga4 連接"
    fi
  fi

  # Python library 有沒有裝
  if python3 -c "import google.analytics.data" 2>/dev/null; then
    ok "google-analytics-data Python 套件已安裝"
  else
    fail "google-analytics-data 套件沒裝。執行 sudo pip install google-analytics-data google-auth-oauthlib"
  fi
else
  info "GA4 未連接（可選設定）。要用 GA4 自動模式請在 Bot 傳 /ga4 連接"
fi


echo ""
echo -e "${BOLD}${BLUE}════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  診斷摘要${RESET}"
echo -e "${BOLD}${BLUE}════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${GREEN}✅ 通過：${PASS}${RESET}    ${YELLOW}⚠️  警告：${WARN}${RESET}    ${RED}❌ 錯誤：${FAIL}${RESET}"
echo ""

if [ ${#ISSUES[@]} -gt 0 ]; then
  echo -e "${BOLD}  需要處理的項目：${RESET}"
  for issue in "${ISSUES[@]}"; do
    echo -e "    $issue"
  done
  echo ""
fi

# 最近的 error 日誌
if [ "$FAIL" -gt 0 ] || [ "$WARN" -gt 0 ]; then
  echo -e "${BOLD}  最近 OpenClaw 日誌（錯誤優先，最多 10 行）：${RESET}"
  echo ""
  journalctl -u openclaw -p warning -n 10 --no-pager 2>/dev/null \
    | sed 's/^/    /' \
    || echo "    （無法讀取日誌）"
  echo ""
fi

# 可以複製給老師的一行總結
echo -e "${BOLD}  要回報給老師？複製下面這段：${RESET}"
echo ""
echo "    ────────────────────────────────"
echo "    OpenClaw 診斷：✅${PASS} ⚠️${WARN} ❌${FAIL}"
echo "    Node: ${NODE_VER:-none}｜Skills: ${SKILL_COUNT:-0}｜Gateway: HTTP ${HTTP_STATUS:-000}"
echo "    Public IP: ${PUBLIC_IP:-unknown}"
echo "    ────────────────────────────────"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  echo -e "  ${GREEN}🎉  一切正常！傳 /d01 給 Bot 開始使用${RESET}"
elif [ "$FAIL" -eq 0 ]; then
  echo -e "  ${YELLOW}基本能跑，但有 ${WARN} 個警告項建議處理${RESET}"
else
  echo -e "  ${RED}有 ${FAIL} 個嚴重錯誤需要先修，龍蝦可能無法正常運作${RESET}"
fi
echo ""
