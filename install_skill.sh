#!/bin/bash
set -euo pipefail
# =============================================================================
#  🦞  安裝／更新單一 Skill（電商班）
#
#  在 Oracle VM 上執行（必須 sudo）：
#    curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/install_skill.sh \
#      -o install_skill.sh && chmod +x install_skill.sh && sudo ./install_skill.sh d01-ecom-init
#
#  用途：
#    • 安裝或更新課後新增的單一 skill
#    • 快速 hotfix 某個 skill 而不動其他
#    • 若要一次裝全部 skills，請跑 bootstrap.sh 的 STEP 6
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✅${NC}  $1"; }
info() { echo -e "  ${DIM}▸${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠️ ${NC}  $1"; }
err()  { echo -e "  ${RED}❌${NC}  $1"; exit 1; }

# ── 必須是 root ──────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  err "請用 sudo 執行：sudo ./install_skill.sh <skill-name>"
fi

SKILL_NAME="${1:-}"
[[ -z "$SKILL_NAME" ]] && err "請指定 skill 名稱，例如：sudo ./install_skill.sh d01-ecom-init"

REPO_OWNER="Joanna8521"
REPO_NAME="openclaw_ecom"
SKILLS_DIR="/root/.openclaw/skills"
PAT_FILE="/root/.openclaw/skills_pat"
LEGACY_ENV_FILE="/etc/openclaw.env"

echo ""
echo -e "${BOLD}${CYAN}  🦞  安裝／更新 Skill：$SKILL_NAME${NC}"
echo ""

# ── 取得 PAT（4 層 fallback，對齊新 bootstrap） ─────────────────────────────
PAT=""

# 1. 環境變數
if [[ -n "${GITHUB_PAT:-}" ]]; then
  PAT="$GITHUB_PAT"
  ok "使用環境變數中的 PAT"
fi

# 2. 新版位置：/root/.openclaw/skills_pat（bootstrap 寫入的 raw PAT）
if [[ -z "$PAT" && -f "$PAT_FILE" ]]; then
  PAT=$(cat "$PAT_FILE" 2>/dev/null || echo "")
  [[ -n "$PAT" ]] && ok "從 $PAT_FILE 讀取 PAT"
fi

# 3. 舊版位置：/etc/openclaw.env（相容舊安裝）
if [[ -z "$PAT" && -f "$LEGACY_ENV_FILE" ]]; then
  PAT=$(grep "^GITHUB_PAT=" "$LEGACY_ENV_FILE" 2>/dev/null | cut -d= -f2- || echo "")
  [[ -n "$PAT" ]] && ok "從 $LEGACY_ENV_FILE 讀取 PAT（舊版位置）"
fi

# 4. 請學員手動輸入
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
      mkdir -p /root/.openclaw
      echo -n "$PAT" > "$PAT_FILE"
      chmod 600 "$PAT_FILE"
      ok "PAT 已儲存到 $PAT_FILE"
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
  warn "$SKILLS_DIR 不存在，建立中..."
  mkdir -p "$SKILLS_DIR"
fi

# ── 下載 skill ───────────────────────────────────────────────────────────────
info "從 GitHub 下載 $SKILL_NAME..."

API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/skills/${SKILL_NAME}/SKILL.md"

HTTP_CODE=$(curl -s -o /tmp/skill_download.md -w "%{http_code}" \
  -H "Authorization: token ${PAT}" \
  -H "Accept: application/vnd.github.v3.raw" \
  "$API_URL")

if [[ "$HTTP_CODE" == "404" ]]; then
  err "找不到 skill「$SKILL_NAME」，請確認名稱是否正確（例如 d01-ecom-init、e01-competitor-price）"
elif [[ "$HTTP_CODE" == "401" ]]; then
  err "PAT 驗證失敗，請確認 token 有效且有 repo read 權限"
elif [[ "$HTTP_CODE" != "200" ]]; then
  err "下載失敗（HTTP $HTTP_CODE），請稍後再試"
fi

# ── 安裝到 skills 目錄 ───────────────────────────────────────────────────────
DEST_DIR="${SKILLS_DIR}/${SKILL_NAME}"
mkdir -p "$DEST_DIR"
cp /tmp/skill_download.md "${DEST_DIR}/SKILL.md"
chmod 644 "${DEST_DIR}/SKILL.md"
rm -f /tmp/skill_download.md
ok "已安裝到 $DEST_DIR"

# ── 重啟 OpenClaw ────────────────────────────────────────────────────────────
info "重啟 OpenClaw 載入新 skill..."
systemctl restart openclaw
sleep 2

if systemctl is-active --quiet openclaw 2>/dev/null; then
  ok "OpenClaw 重啟成功"
else
  warn "重啟似乎有問題，請執行 journalctl -u openclaw -n 30 --no-pager 查看錯誤"
fi

# ── 完成 ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}  ✅  $SKILL_NAME 安裝完成！${NC}"
echo ""
echo "  在 LINE（主要）或 Telegram / Discord 傳：/${SKILL_NAME%%-*}"
echo "  （例如 d01-ecom-init → 傳 /d01）"
echo ""
