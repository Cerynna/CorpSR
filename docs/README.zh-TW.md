<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>公會軟預定（SR）積分系統，全部在遊戲內完成。</b><br>
  魔獸世界經典版 ·「Forever」用戶端（Interface 16001）
</p>

<p align="center">
  <a href="https://github.com/Cerynna/CorpSR/blob/main/README.md">English</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.fr.md">Français</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.de.md">Deutsch</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.es.md">Español</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.pt.md">Português</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.it.md">Italiano</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">Русский</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-CN.md">简体中文</a> ·
  <b>繁體中文</b> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ko.md">한국어</a>
</p>

![我的 SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/MesSR.png)

CorpSR 在遊戲內管理你公會的軟預定（SR）：每位成員預定想要的物品，拾取者分配戰利品，插件讀取 `/roll` 擲骰、排名並保存歷史。每次 SR 沒拿到，你都會在該物品上獲得積分，下一次擲骰就更強。

沒有網站，沒有匯出，沒有試算表。資料只透過公會的插件頻道傳輸，每位成員都保存完整副本：幹部不在線也不會遺失任何東西。

## 功能

- **每週 SR**：每週 2 個（會長設定），可選任何團隊副本的任何物品。允許雙重 SR。
- **積分**：你預定的物品沒拿到 → 該物品 +10 積分。你的 SR 擲骰 = 擲骰 + 積分。
- **明確的優先順序**：SR > +1 > +1 已拾取 > +2 > 塑形，依擲骰範圍判斷。
- **團員視窗**：物品、你的積分、每種擲骰一個按鈕、時間條、「放棄」。
- **分配視窗**（給拾取者）：即時擲骰、平手、可自選獲勝者、剩餘物品（自由擲骰、公會銀行、分解）。
- **團隊通告**：每件物品開始和結束時通告。
- **交付**：嘗試交易、準備好的密語、待交付清單、本次活動的分解者。
- **密語 `!SR`**：給沒有安裝插件的成員使用。
- **完整歷史**：一切都有記錄；修正和撤銷需要填寫理由，並且可以復原。
- **會長設定**：數值和各會階權限，完全重置。
- **示範模式**：什麼都不會傳送給公會，可以隨意試用。
- **10 種語言**：英文、法文、德文、西班牙文、葡萄牙文、義大利文、俄文、簡體中文、繁體中文、韓文。

## 規則

| 擲骰類型 | 擲骰 | 總分 |
|---|---|---|
| **SR** | `/roll 110` | 擲骰 + 你在該物品上的積分 |
| **+1**（主天賦） | `/roll 100` | 擲骰 |
| **+1 已拾取**（主天賦，本週已用 +1 贏過一件物品） | `/roll 100` | 擲骰 |
| **+2**（副天賦） | `/roll 50` | 擲骰 |
| **塑形** | `/roll 20` | 擲骰 |

- **類別高者勝**，無論擲骰點數：SR 永遠勝過 +1。同一類別內總分最高者獲勝。平手時，平手者重新擲骰。
- **積分**：你用已有的積分擲骰（第一次為 0）。物品擲骰結束後，所有預定了它、在團隊中且沒拿到的人，在該物品上獲得**每個 SR +10**（雙重 SR 為 +20）。獲勝者不加分；如果是用 SR 贏的，該物品積分歸零。點擊「放棄」的人也不加分。
- **積分會保留**：換預定物品時，舊物品的積分會留著，等你再次預定它。
- **贏得的物品會用掉你本週的 SR**：如果有多個首領會掉落它，下週之前你不能再用 SR 擲它。
- **+1 已拾取**：從你本週（或本次活動，會長設定）第一次用 +1 獲勝開始。用 SR、+2、塑形或自由擲骰贏得的物品不算。
- **只有你的第一次有效擲骰算數。** 掉落 N 件時，前 N 名獲勝。
- 所有數值（積分、SR 數量、雙重 SR、擲骰範圍）都是會長設定。

## 一次團隊活動

**幹部**

1. **活動**分頁 → **新建活動**。
2. 拾取者打開首領的戰利品：**分配視窗**會自動打開。也可以在背包中按住 Alt 並左鍵點擊一件物品。
3. 選擇物品，然後點**開始**：你的點擊會在團隊頻道通告該物品、擲骰範圍和時間。
4. 擲骰即時進入。時間到後，點**確認**（或**平手重擲**）：你的點擊會通告獲勝者。
5. CorpSR 會嘗試與獲勝者交易並放入物品。否則，一個按鈕上會準備好密語。**待交付**分頁會記住還欠誰什麼。
6. 沒人要？自由擲骰、公會銀行或分解。

![分配視窗](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Attribution.png)

**團員**

- **我的 SR** 分頁：點擊物品進行預定，再點一次為雙重 SR，右鍵移除一個。本週第一件物品開始擲骰時（或幹部鎖定時），SR 會被鎖定。
- 物品掉落時，你的**擲骰視窗**會顯示你能擲的類型。點一下就替你執行正確的 `/roll`。

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raideur.png" width="450" alt="團員視窗">
</p>

- **積分**分頁：所有人的積分，依物品列出。**歷史**分頁：發生過的一切，誰做的、何時做的。
- 沒有插件？向幹部密語 `!SR [物品] [物品]`（物品連結，連在一起或分開，或物品編號）。只發 `!SR` 會告訴你本週的 SR。

## 各會階權限

會長依會階決定誰能做什麼（設定分頁）。預定自己的 SR 不需要任何權限。

| 權限 | 允許 |
|---|---|
| **活動** | 開啟、鎖定、結束、重新開啟、重新命名或刪除活動；為密語 `!SR` 的成員登記 SR |
| **分配** | 開始一件物品的擲骰、讀取擲骰、確認獲勝者、送進公會銀行或分解 |
| **修正** | 修正玩家在某物品上的積分，必須填寫理由 |
| **撤銷** | 撤銷一條歷史記錄，必須填寫理由 |
| **物品** | 從已知物品中移除物品（任何人都可以新增） |

## 指令

| 指令 | 作用 |
|---|---|
| `/csr` | 打開或關閉 CorpSR 視窗 |
| `/csr attrib` | 打開或關閉分配視窗（也可以右鍵點擊小地圖按鈕） |
| `/csr demo` | 開始或停止示範模式 |
| `/csr minimap` | 顯示或隱藏小地圖按鈕 |
| `/csr sync` | 向公會請求最新資料 |

CorpSR 還會在**公會與社群**視窗中加一個分頁；安裝了 [CorpUI](https://github.com/Cerynna/CorpUI)（可選）時，還會在 `/corp` 中加一個頁面。

## 須知

- **遊戲禁止插件自行在聊天頻道發言或傳送密語。** 所以通告和密語都透過按鈕完成：你的點擊傳送訊息，就像你親手輸入一樣。戰鬥中這些按鈕會隱藏。
- **在副本中**，密語內容可能對插件隱藏：請在進本前傳送 `!SR`。
- 資料**只與你的公會**透過插件頻道共享，不會離開遊戲。

## 安裝

- **Wago**：[addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr)，用 Wago 應用程式或手動安裝。
- **手動**：把 `CorpSR` 資料夾放到魔獸世界經典版目錄的 `Interface\AddOns` 中，然後重新啟動遊戲。

## 截圖

| | |
|---|---|
| ![積分](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Points.png) | ![歷史](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Historique.png) |
| ![活動](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Session.png) | ![待交付](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Remise.png) |
| ![設定](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Reglages.png) | ![已知物品](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raids.png) |

截圖中的插件為英文介面；遊戲內為繁體中文。所有視窗的英文和法文圖片：[`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images)。這些圖片依插件在示範模式下的真實版面繪製。

## 開發

程式結構、詳細規則和測試（法文）：[`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md)。
