# 🦞 AICLAW x OpenClaw — 電商龍蝦技能包

> 課程專用，請勿外傳

---

## 快速安裝

### STEP 1：在 Oracle Cloud Shell 建立 VM

```bash
curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/setup_vm.sh | bash
```

建立完成後，Cloud Shell 會輸出 SSH 連線指令和 VM 的 Public IP。

---

### STEP 2：SSH 進入 VM

```bash
ssh -i ~/.ssh/openclaw_key ubuntu@你的VM的IP
```

---

### STEP 3：在 VM 內安裝龍蝦 + 全部 98 個 Skill

```bash
curl -fsSL https://raw.githubusercontent.com/Joanna8521/openclaw-install_ecom/main/bootstrap.sh | sudo bash
```

安裝過程會引導你輸入：
- Skills 存取碼（老師提供）
- AI 引擎（Claude / Gemini / OpenAI）
- LINE Bot Token
- Google 憑證（可選填）

---

## Skill 清單

### 通用基礎 C01–C10

| Skill | 說明 |
|-------|------|
| ☁️ C01 | Oracle Cloud 部署管理 |
| 🔗 C02 | Google 服務整合（Sheets / Drive / Calendar） |
| ✈️ C03 | Telegram Bot 設定與管理 |
| 💚 C04 | LINE Bot 設定與管理 |
| 🌐 C05 | 沙盒瀏覽器 |
| 🕷️ C06 | 基礎爬蟲 |
| 📊 C07 | Google Sheets 資料庫 |
| 📁 C08 | Google Drive 管理 |
| 📋 C09 | 每日報告 |
| ⏰ C10 | 定時排程 |

---

### 電商營運 E01–E10

| Skill | 說明 |
|-------|------|
| 🔍 E01 | 競品價格監控 |
| ⭐ E02 | 評價監控 |
| 📦 E03 | 庫存預警 |
| 🚨 E04 | 訂單異常偵測 |
| ✏️ E05 | 商品標題優化 |
| 💬 E06 | 負評回覆生成 |
| 📝 E07 | 商品描述生成 |
| 🎯 E08 | 促銷活動規劃 |
| 🏆 E09 | 暢銷榜追蹤 |
| 📢 E10 | 廣告成效監控 |

---

### 行銷自動化 E11–E38

| Skill | 說明 |
|-------|------|
| ⚖️ E11 | 跨平台比價 |
| ✅ E12 | 商品上架品質檢查 |
| 📦 E13 | 退貨原因分析 |
| 🤖 E14 | 客服 FAQ Bot |
| 🚚 E15 | 物流異常提醒 |
| 🌏 E16 | 跨境稅務試算 |
| 💰 E17 | 利潤計算器 |
| 🏭 E18 | 採購管理 |
| 📣 E19 | 廣告文案生成 |
| 📅 E20 | 行銷行事曆 |
| 📧 E21 | EDM 電子報生成 |
| 👂 E22 | 社群監控 |
| 🌟 E23 | KOL 名單管理 |
| 🔬 E24 | A/B 測試分析 |
| 🎯 E25 | 再行銷受眾規劃 |
| 🔗 E26 | UTM 追蹤碼管理 |
| 💚 E27 | LINE 官方帳號管理 |
| 🎨 E28 | 廣告素材建議 |
| 🤝 E29 | 聯盟行銷管理 |
| 🎉 E30 | 節日行銷快報 |
| 👥 E31 | 推薦人追蹤 |
| 🛒 E32 | 棄單挽回 |
| 🎬 E33 | 短影音腳本生成 |
| 👤 E34 | 顧客分眾（RFM） |
| 📡 E35 | 直播腳本與管理 |
| ⭐ E36 | 評價邀請自動化 |
| 📸 E37 | UGC / 開箱文管理 |
| 📱 E38 | 社群貼文排程 |

---

### SEO 專業 E39–E58

| Skill | 說明 |
|-------|------|
| 🔍 E39 | 關鍵字研究 |
| 📈 E40 | 關鍵字排名追蹤 |
| 🧠 E41 | 搜尋意圖分析 |
| 🔎 E42 | SERP 搜尋結果頁分析 |
| 🕳️ E43 | 內容缺口分析 |
| 🏥 E44 | SEO 健康檢查 |
| 🕷️ E45 | 技術 SEO 爬蟲 |
| 🕸️ E46 | 內部連結優化 |
| ⚡ E47 | Core Web Vitals 監控 |
| 🔗 E48 | 反向連結監控 |
| 🏷️ E49 | Schema 結構化資料生成 |
| 🛍️ E50 | 電商 SEO 專項 |
| 📍 E51 | Google 商家檔案管理 |
| ✍️ E52 | AI SEO 文章生成 |
| 🕵️ E53 | 競品流量分析 |
| 🏷️ E54 | Meta 標籤批量優化 |
| 🚀 E55 | 頁面速度監控 |
| 🖥️ E56 | Google Search Console 整合 |
| 📊 E57 | GA4 × SEO 整合分析 |
| 📋 E58 | SEO 週報 |

---

### 數據分析 E59–E78

| Skill | 說明 |
|-------|------|
| 📊 E59 | GA4 全站分析摘要 |
| 📣 E60 | 廣告成效分析 |
| 💎 E61 | LTV 顧客終身價值計算 |
| 🎯 E62 | CAC 獲客成本追蹤 |
| 🔽 E63 | 轉換漏斗分析 |
| 📅 E64 | 月度行銷報告 |
| 🗂️ E65 | 多平台數據整合 |
| ⚖️ E66 | 付費 vs 自然流量比較 |
| 🛒 E67 | AOV 客單價追蹤 |
| 🔄 E68 | 回購率分析 |
| 📆 E69 | 每日營收報告 |
| 👑 E70 | 會員忠誠度管理 |
| 🔍 E71 | 競品廣告監控 |
| 🏆 E72 | 商品績效分析 |
| 📦 E73 | 庫存周轉率分析 |
| ↩️ E74 | 退貨率分析 |
| ⏰ E75 | 熱銷時段分析 |
| 🎯 E76 | 促銷活動效果回顧 |
| 🚨 E77 | 數據異常偵測 |
| 📋 E78 | 數據分析週報 |

---

### 內容與發布 E79–E88

| Skill | 說明 |
|-------|------|
| 🚀 E79 | 多平台商品同步發布 |
| 📱 E80 | 社群內容跨平台發布 |
| 🎪 E81 | 促銷活動跨平台同步 |
| 📨 E82 | 電子報 + LINE 同步發送 |
| 🗃️ E83 | 圖文素材分發管理 |
| 📆 E84 | 跨渠道內容日曆 |
| 📋 E85 | 商品上架模板庫 |
| 🔄 E86 | 內容格式轉換 |
| ⚡ E87 | 緊急更新與下架 |
| ✅ E88 | 發布狀態追蹤 |

---

## 常用指令

```bash
# 查看龍蝦狀態
sudo systemctl status openclaw

# 重新啟動龍蝦
sudo systemctl restart openclaw

# 查看即時 log
sudo journalctl -u openclaw -f

# 更新 Skills
cd /opt/openclaw/skills && git pull

# 更新主程式
cd /opt/openclaw && git pull
```

---

## 問題回報

Telegram 找老師，或在課程群組提問。
