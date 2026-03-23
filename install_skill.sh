#!/bin/bash
set -euo pipefail
# =============================================================================
#  🦞  安裝 D01 電商初始化診斷 Skill
#
#  在 Oracle VM 上執行：
#    curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/install_skill.sh | bash -s d01-ecom-init
#
#  也可以用來安裝任何單一 skill：
#    curl -fsSL .../install_skill.sh | bash -s <skill-name>
# =============================================================================

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m'
CYAN='\033[0;36m';BOLD='\033[1m';DIM='\033[2m';NC='\033[0m'

ok()      { echo -e "  ${GREEN}✅${NC}  $1"; }
info()    { echo -e "  ${DIM}▸${NC}  $1"; }
warn()    { echo -e "  ${YELLOW}⚠️ ${NC}  $1"; }
err()     { echo -e "  ${RED}❌${NC}  $1"; exit 1; }

SKILL_NAME="${1:-}"
[[ -z "$SKILL_NAME" ]] && err "請指定 skill 名稱，例如：bash install_skill.sh d01-ecom-init"

REPO_OWNER="Joanna8521"
REPO_NAME="openclaw_ecom"
SKILLS_DIR="/opt/openclaw/skills"

echo ""
echo -e "${BOLD}${CYAN}  🦞  安裝 Skill：$SKILL_NAME${NC}"
echo ""

# ── 確認 PAT ────────────────────────────────────────────────────────────────
PAT=""

# 先從環境變數找
if [[ -n "${GITHUB_PAT:-}" ]]; then
  PAT="$GITHUB_PAT"
fi

# 再從 openclaw 設定找
if [[ -z "$PAT" ]]; then
  ENV_FILE="/etc/openclaw.env"
  if [[ -f "$ENV_FILE" ]]; then
    PAT=$(grep "^GITHUB_PAT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 || echo "")
  fi
fi

# 還是找不到，請學員輸入
if [[ -z "$PAT" ]]; then
  echo "  需要 GitHub PAT 來下載 skill 檔案"
  echo "  （就是當初 bootstrap 時填入的那組 token）"
  echo ""
  read -rp "  請貼上 GitHub PAT: " PAT
  [[ -z "$PAT" ]] && err "PAT 不能為空"
fi

# ── 確認 skills 目錄存在 ────────────────────────────────────────────────────
if [[ ! -d "$SKILLS_DIR" ]]; then
  err "找不到 $SKILLS_DIR，請確認 OpenClaw 已正確安裝（先跑 bootstrap.sh）"
fi

# ── 下載 skill ───────────────────────────────────────────────────────────────
info "從 GitHub 下載 $SKILL_NAME..."

API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/skills/${SKILL_NAME}/SKILL.md"

HTTP_CODE=$(curl -s -o /tmp/skill_download.json -w "%{http_code}" \
  -H "Authorization: token ${PAT}" \
  -H "Accept: application/vnd.github.v3.raw" \
  "$API_URL")

if [[ "$HTTP_CODE" == "404" ]]; then
  err "找不到 skill「$SKILL_NAME」，請確認名稱是否正確"
elif [[ "$HTTP_CODE" == "401" ]]; then
  err "PAT 驗證失敗，請確認 token 有效且有 repo read 權限"
elif [[ "$HTTP_CODE" != "200" ]]; then
  err "下載失敗（HTTP $HTTP_CODE），請稍後再試"
fi

# ── 安裝到 skills 目錄 ───────────────────────────────────────────────────────
DEST_DIR="${SKILLS_DIR}/${SKILL_NAME}"
mkdir -p "$DEST_DIR"
cp /tmp/skill_download.json "${DEST_DIR}/SKILL.md"
ok "已安裝到 $DEST_DIR"

# ── 重啟 OpenClaw ────────────────────────────────────────────────────────────
info "重啟 OpenClaw 載入新 skill..."
sudo systemctl restart openclaw
sleep 2

if systemctl is-active --quiet openclaw 2>/dev/null; then
  ok "OpenClaw 重啟成功"
else
  warn "重啟似乎有問題，請手動執行：sudo systemctl restart openclaw"
fi

# ── 完成 ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}  ✅  $SKILL_NAME 安裝完成！${NC}"
echo ""
echo "  在 LINE / Telegram / Discord 傳：/d01"
echo "  就可以開始初始化你的電商龍蝦 🦞"
echo ""
