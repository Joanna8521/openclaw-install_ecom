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
ENV_FILE="/etc/openclaw.env"

# 先從環境變數找
if [[ -n "${GITHUB_PAT:-}" ]]; then
  PAT="$GITHUB_PAT"
  ok "使用環境變數中的 PAT"
fi

# 再從 /etc/openclaw.env 找
if [[ -z "$PAT" && -f "$ENV_FILE" ]]; then
  PAT=$(grep "^GITHUB_PAT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 || echo "")
  [[ -n "$PAT" ]] && ok "從 /etc/openclaw.env 讀取 PAT"
fi

# 還是找不到，請學員輸入
if [[ -z "$PAT" ]]; then
  echo ""
  warn "找不到 GitHub PAT，需要手動輸入"
  echo "  ${DIM}（Joanna 在課程群組提供的 github_pat_ 開頭的 token）${NC}"
  echo ""
  while true; do
    read -rs -p "  請貼上 GitHub PAT: " PAT
    echo ""
    if [[ "$PAT" == github_pat_* ]]; then
      ok "PAT 格式正確"
      # 存起來，下次就不用再問了
      sudo touch "$ENV_FILE"
      sudo chmod 600 "$ENV_FILE"
      sudo sed -i '/^GITHUB_PAT=/d' "$ENV_FILE" 2>/dev/null || true
      echo "GITHUB_PAT=${PAT}" | sudo tee -a "$ENV_FILE" > /dev/null
      ok "PAT 已儲存到 $ENV_FILE"
      break
    elif [[ -z "$PAT" ]]; then
      warn "PAT 不能為空，請重新輸入"
    else
      warn "格式不對，PAT 應以 github_pat_ 開頭，請重新輸入"
    fi
  done
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
