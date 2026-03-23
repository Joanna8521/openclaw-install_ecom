#!/bin/bash
set -euo pipefail
# =============================================================================
#  🦞  OpenClaw VM 一鍵建立腳本（AWS 版）
#      電商+行銷+SEO 班 備案方案
#
#  適用場景：Oracle Cloud 申請不過、GCP 預算考量時的備案
#
#  費用說明：
#    本腳本建立 t3.medium（2 vCPU / 4GB RAM）
#    費用約 NT$900–1,100 /月（ap-northeast-1 東京區）
#    若選新加坡區（ap-southeast-1）費用相近
#    ⚠️  AWS 比 GCP 略貴，比 Hetzner 貴約 6 倍
#
#  在 AWS CloudShell 執行：
#    curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/setup_vm_aws.sh -o setup_vm_aws.sh && bash setup_vm_aws.sh
#
#  自動完成：
#    1. 確認 AWS CLI 設定和帳號
#    2. 建立 Key Pair（SSH 金鑰）
#    3. 建立 Security Group（開放 Port 22 + 80 + 443）
#    4. 查詢最新 Ubuntu 22.04 AMI
#    5. 建立 EC2 t3.medium 實例
#    6. 輸出 SSH 連線指令 + 下一步提示
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

# ── 預設設定 ─────────────────────────────────────────────────────────────────
INSTANCE_NAME="openclaw-ecom-vm"
INSTANCE_TYPE="t3.medium"         # 2 vCPU / 4GB RAM
REGION="ap-northeast-1"           # 東京（台灣最近）
DISK_SIZE="30"                    # GB
KEY_NAME="openclaw-ecom-key"
SG_NAME="openclaw-ecom-sg"

# ── Banner ──────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🦞  OpenClaw VM 一鍵建立程式          ║
  ║         電商+行銷+SEO 班 × AWS 備案方案   ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
BANNER
echo -e "${NC}"
echo "  ⚠️  費用提醒："
echo "  本腳本建立 t3.medium（2 vCPU / 4GB RAM / 東京區）"
echo '  費用約 NT\$900–1,100 / 月（不含流量）'
echo ""
echo "  備案方案優先順序（由低到高）："
echo '  Oracle Cloud  → NT\$0/月（首選，永久免費）'
echo '  Hetzner CX22  → NT\$140/月（申請快，推薦備案）'
echo '  GCP e2-medium → NT\$700–900/月'
echo '  AWS t3.medium → NT\$900–1,100/月（本腳本）'
echo ""
read -rp "  確認要繼續用 AWS 建立 VM？[y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "  已取消"; exit 0; }

# ── STEP 1：確認 AWS CLI 環境 ─────────────────────────────────────────────────
section "STEP 1｜確認 AWS 環境"

if ! command -v aws &>/dev/null; then
  err "找不到 aws CLI。請在 AWS CloudShell 執行此腳本，或安裝 AWS CLI v2。"
fi
ok "AWS CLI 已就緒"

# 確認身份
info "確認 AWS 帳號身份..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [[ -z "$ACCOUNT_ID" ]]; then
  err "無法取得 AWS 帳號。請確認已設定 AWS credentials（aws configure 或 CloudShell 環境）。"
fi
ok "AWS 帳號：$ACCOUNT_ID"

# ── STEP 2：選擇區域 ─────────────────────────────────────────────────────────
section "STEP 2｜選擇區域"

echo "  建議區域（台灣附近）："
echo '  1) ap-northeast-1  東京（延遲最低，約 NT\$1,000/月）'
echo '  2) ap-southeast-1  新加坡（費用相近，約 NT\$950/月）'
echo "  3) 自訂"
echo ""
read -rp "  選擇 [1/2/3，預設 1]: " region_choice

case "${region_choice:-1}" in
  2)
    REGION="ap-southeast-1"
    ;;
  3)
    read -rp "  請輸入 Region（例如 us-east-1）: " REGION
    ;;
  *)
    REGION="ap-northeast-1"
    ;;
esac
ok "區域：$REGION"

# 設定 region 讓後續指令生效
export AWS_DEFAULT_REGION="$REGION"

# ── STEP 3：建立或取得 Key Pair ──────────────────────────────────────────────
section "STEP 3｜建立 SSH Key Pair"

KEY_FILE="$HOME/${KEY_NAME}.pem"

EXISTING_KEY=$(aws ec2 describe-key-pairs \
  --key-names "$KEY_NAME" \
  --query "KeyPairs[0].KeyName" \
  --output text 2>/dev/null || echo "None")

if [[ "$EXISTING_KEY" == "$KEY_NAME" ]]; then
  warn "Key Pair「$KEY_NAME」已存在"
  if [[ -f "$KEY_FILE" ]]; then
    ok "本機金鑰檔案存在：$KEY_FILE"
  else
    warn "本機找不到 $KEY_FILE，SSH 時可能需要重建 Key Pair"
    read -rp "  要刪掉舊的重新建立嗎？[y/N] " rekey
    if [[ "${rekey,,}" == "y" ]]; then
      aws ec2 delete-key-pair --key-name "$KEY_NAME"
      aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query "KeyMaterial" \
        --output text > "$KEY_FILE"
      chmod 400 "$KEY_FILE"
      ok "新 Key Pair 建立完成：$KEY_FILE"
    fi
  fi
else
  info "建立 Key Pair..."
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query "KeyMaterial" \
    --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  ok "Key Pair 建立完成：$KEY_FILE"
fi

echo ""
warn "金鑰檔案路徑：$KEY_FILE"
echo "  ⚠️  請立即備份此金鑰，遺失後無法重新下載！"
echo "  在 CloudShell 可用以下指令下載："
echo "  （Actions → Download file → 輸入路徑）"

# ── STEP 4：建立 Security Group ──────────────────────────────────────────────
section "STEP 4｜設定 Security Group（防火牆）"

# 取得預設 VPC
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null || echo "")

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  err "找不到預設 VPC，請先在 AWS Console 建立預設 VPC。"
fi
ok "VPC：$VPC_ID"

# 檢查 SG 是否已存在
EXISTING_SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || echo "None")

if [[ "$EXISTING_SG" != "None" && -n "$EXISTING_SG" ]]; then
  ok "Security Group 已存在：$EXISTING_SG"
  SG_ID="$EXISTING_SG"
else
  info "建立 Security Group..."
  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "OpenClaw 電商+行銷+SEO 班 LINE Webhook + HTTPS" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" \
    --output text)

  # 開放 Port 22（SSH）、80（HTTP）、443（HTTPS）
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --ip-permissions \
      "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0,Description=SSH}]" \
      "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTP}]" \
      "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description=HTTPS}]" \
    2>/dev/null

  ok "Security Group 建立完成：$SG_ID（Port 22 + 80 + 443 開放）"
fi

# ── STEP 5：查詢最新 Ubuntu 22.04 AMI ───────────────────────────────────────
section "STEP 5｜查詢 Ubuntu 22.04 AMI"

info "查詢 $REGION 最新 Ubuntu 22.04 LTS AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters \
    "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    "Name=state,Values=available" \
    "Name=architecture,Values=x86_64" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text 2>/dev/null || echo "")

if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
  err "無法查詢到 Ubuntu 22.04 AMI，請確認 Region 正確。"
fi
ok "AMI：$AMI_ID（Ubuntu 22.04 LTS 最新版）"

# ── STEP 6：確認是否有同名實例 ───────────────────────────────────────────────
section "STEP 6｜確認環境"

info "檢查是否有同名 EC2 實例..."
EXISTING_INSTANCE=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Name,Values=$INSTANCE_NAME" \
    "Name=instance-state-name,Values=running,stopped,pending" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || echo "None")

if [[ "$EXISTING_INSTANCE" != "None" && -n "$EXISTING_INSTANCE" ]]; then
  warn "偵測到同名實例「$INSTANCE_NAME」已存在（$EXISTING_INSTANCE）"
  echo ""
  read -rp "  要終止舊的重新建立嗎？[y/N] " del_confirm
  if [[ "${del_confirm,,}" == "y" ]]; then
    info "終止舊實例..."
    aws ec2 terminate-instances --instance-ids "$EXISTING_INSTANCE" >/dev/null
    info "等待終止完成（約 30 秒）..."
    aws ec2 wait instance-terminated --instance-ids "$EXISTING_INSTANCE"
    ok "舊實例已終止"
  else
    echo "  已取消。如需使用現有實例，請直接 SSH 進去跑 bootstrap.sh"
    exit 0
  fi
fi

# ── STEP 7：建立 EC2 實例 ────────────────────────────────────────────────────
section "STEP 7｜建立 EC2 實例（t3.medium / Ubuntu 22.04）"

info "建立 EC2 實例，約需 30–60 秒..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$DISK_SIZE,\"VolumeType\":\"gp3\"}}]" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query "Instances[0].InstanceId" \
  --output text)

ok "EC2 實例建立中：$INSTANCE_ID"

info "等待實例啟動（約 30–60 秒）..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
ok "實例已啟動！"

# ── STEP 8：取得公網 IP ──────────────────────────────────────────────────────
section "STEP 8｜取得連線資訊"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text 2>/dev/null || echo "")

if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "None" ]]; then
  warn "無法取得 Public IP，請至 AWS Console 查看"
  PUBLIC_IP="<請至 AWS Console 查看 EC2 的 Public IP>"
fi
ok "Public IP：$PUBLIC_IP"

# ── 完成畫面 ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
cat << 'SUCCESS'
  ╔═══════════════════════════════════════════╗
  ║                                           ║
  ║     🎉  EC2 實例建立完成！                ║
  ║                                           ║
  ╚═══════════════════════════════════════════╝
SUCCESS
echo -e "${NC}"

echo "  ── VM 資訊 ─────────────────────────────────"
echo "  Instance ID：$INSTANCE_ID"
echo "  Instance 名稱：$INSTANCE_NAME"
echo "  區域：   $REGION"
echo "  規格：   t3.medium（2 vCPU / 4GB RAM）"
echo "  IP：     $PUBLIC_IP"
echo ""
echo "  ── SSH 連線指令 ─────────────────────────────"
echo ""
echo "  ssh -i $KEY_FILE ubuntu@$PUBLIC_IP"
echo ""
warn "首次連線需等待約 30 秒讓 sshd 完全啟動"
echo ""
echo "  ── 進入 VM 後，貼上以下指令安裝龍蝦 ────────"
echo ""
echo "  curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/bootstrap.sh | sudo bash"
echo ""
echo "  ── ⚠️  費用提醒 ──────────────────────────────"
echo '  AWS EC2 費用：約 NT\$900–1,100 / 月'
echo "  不使用時可在 AWS Console 停止（Stop）實例暫停計費"
echo '  （停止後不計 CPU/RAM 費用，只計磁碟費用約 NT$25/月）'
echo ""
echo "  ── ⚠️  IP 注意事項 ──────────────────────────"
echo "  AWS EC2 停止後重啟，Public IP 會改變！"
echo "  如需固定 IP，請在 AWS Console 申請 Elastic IP（固定 IP）"
echo '  Elastic IP 閒置時會收費（約 NT\$110/月），使用中免費'
echo ""
echo "  ── LINE Webhook 設定 ────────────────────────"
echo "  Webhook URL：http://$PUBLIC_IP/line/webhook"
echo "  （安裝完龍蝦後再設定，需要 HTTPS 可用 ngrok）"
echo ""
echo "  ── 金鑰備份提醒 ─────────────────────────────"
echo "  金鑰路徑：$KEY_FILE"
echo "  ⚠️  請立即備份！CloudShell 環境重置後金鑰會消失"
echo ""
