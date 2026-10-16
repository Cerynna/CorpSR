<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>公会软预定（SR）积分系统，全部在游戏内完成。</b><br>
  魔兽世界经典版 ·“Forever”客户端（Interface 16001）
</p>

<p align="center">
  <a href="https://github.com/Cerynna/CorpSR/blob/main/README.md">🇬🇧 English</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.fr.md">🇫🇷 Français</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.de.md">🇩🇪 Deutsch</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.es.md">🇪🇸 Español</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.pt.md">🇧🇷 Português</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.it.md">🇮🇹 Italiano</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">🇷🇺 Русский</a> ·
  <b>🇨🇳 简体中文</b> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-TW.md">🇹🇼 繁體中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ko.md">🇰🇷 한국어</a>
</p>

![我的 SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/MesSR.png)

CorpSR 在游戏内管理你公会的软预定（SR）：每位成员预定想要的物品，拾取者分配战利品，插件读取 `/roll` 掷骰、排名并保存历史。每次 SR 没拿到，你都会在该物品上获得积分，下一次掷骰就更强。

没有网站，没有导出，没有表格。数据只通过公会的插件频道传输，每位成员都保存完整副本：官员不在线也不会丢失任何东西。

## 功能

- **每周 SR**：每周 2 个（会长设置），可选任何团队副本的任何物品。允许双重 SR。
- **积分**：你预定的物品没拿到 → 该物品 +10 积分。你的 SR 掷骰 = 掷骰 + 积分。
- **明确的优先级**：SR > +1 > +1 已拾取 > +2 > 幻化，按掷骰范围判断。
- **团员窗口**：物品、你的积分、每种掷骰一个按钮、时间条、“放弃”。
- **分配窗口**（给拾取者）：实时掷骰、平局、可自选获胜者、剩余物品（自由掷骰、公会银行、分解）。
- **团队通告**：每件物品开始和结束时通告。
- **交付**：尝试交易、准备好的密语、待交付清单、本次活动的分解者。
- **密语 `!SR`**：给没有安装插件的成员使用。
- **完整历史**：一切都有记录；修正和撤销需要填写理由，并且可以恢复。
- **会长设置**：数值和各会阶权限，完全重置。
- **演示模式**：什么都不会发送给公会，可以随意试用。
- **10 种语言**：英语、法语、德语、西班牙语、葡萄牙语、意大利语、俄语、简体中文、繁体中文、韩语。

## 规则

| 掷骰类型 | 掷骰 | 总分 |
|---|---|---|
| **SR** | `/roll 110` | 掷骰 + 你在该物品上的积分 |
| **+1**（主天赋） | `/roll 100` | 掷骰 |
| **+1 已拾取**（主天赋，本周已用 +1 赢过一件物品） | `/roll 100` | 掷骰 |
| **+2**（副天赋） | `/roll 50` | 掷骰 |
| **幻化** | `/roll 20` | 掷骰 |

- **类别高者胜**，无论掷骰点数：SR 永远胜过 +1。同一类别内总分最高者获胜。平局时，平局者重新掷骰。
- **积分**：你用已有的积分掷骰（第一次为 0）。物品掷骰结束后，所有预定了它、在团队中且没拿到的人，在该物品上获得**每个 SR +10**（双重 SR 为 +20）。获胜者不加分；如果是用 SR 赢的，该物品积分归零。点击“放弃”的人也不加分。
- **积分会保留**：换预定物品时，旧物品的积分会留着，等你再次预定它。
- **赢得的物品会用掉你本周的 SR**：如果有多个首领会掉落它，下周之前你不能再用 SR 掷它。
- **+1 已拾取**：从你本周（或本次活动，会长设置）第一次用 +1 获胜开始。用 SR、+2、幻化或自由掷骰赢得的物品不算。
- **只有你的第一次有效掷骰算数。** 掉落 N 件时，前 N 名获胜。
- 所有数值（积分、SR 数量、双重 SR、掷骰范围）都是会长设置。

## 一次团队活动

**官员**

1. **活动**标签 → **新建活动**。
2. 拾取者打开首领的战利品：**分配窗口**会自动打开。也可以在背包中按住 Alt 并左键点击一件物品。
3. 选择物品，然后点**开始**：你的点击会在团队频道通告该物品、掷骰范围和时间。
4. 掷骰实时进入。时间到后，点**确认**（或**平局重掷**）：你的点击会通告获胜者。
5. CorpSR 会尝试与获胜者交易并放入物品。否则，一个按钮上会准备好密语。**待交付**标签会记住还欠谁什么。
6. 没人要？自由掷骰、公会银行或分解。

![分配窗口](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Attribution.png)

**团员**

- **我的 SR** 标签：点击物品进行预定，再点一次为双重 SR，右键移除一个。本周第一件物品开始掷骰时（或官员锁定时），SR 会被锁定。
- 物品掉落时，你的**掷骰窗口**会显示你能掷的类型。点一下就替你执行正确的 `/roll`。

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raideur.png" width="450" alt="团员窗口">
</p>

- **积分**标签：所有人的积分，按物品列出。**历史**标签：发生过的一切，谁做的、何时做的。
- 没有插件？向官员密语 `!SR [物品] [物品]`（物品链接，连在一起或分开，或物品编号）。只发 `!SR` 会告诉你本周的 SR。

## 各会阶权限

会长按会阶决定谁能做什么（设置标签）。预定自己的 SR 不需要任何权限。

| 权限 | 允许 |
|---|---|
| **活动** | 开启、锁定、结束、重新开启、重命名或删除活动；为密语 `!SR` 的成员登记 SR |
| **分配** | 开始一件物品的掷骰、读取掷骰、确认获胜者、送进公会银行或分解 |
| **修正** | 修正玩家在某物品上的积分，必须填写理由 |
| **撤销** | 撤销一条历史记录，必须填写理由 |
| **物品** | 从已知物品中移除物品（任何人都可以添加） |

## 命令

| 命令 | 作用 |
|---|---|
| `/csr` | 打开或关闭 CorpSR 窗口 |
| `/csr attrib` | 打开或关闭分配窗口（也可以右键点击小地图按钮） |
| `/csr demo` | 开始或停止演示模式 |
| `/csr minimap` | 显示或隐藏小地图按钮 |
| `/csr sync` | 向公会请求最新数据 |

CorpSR 还会在**公会与社区**窗口中加一个标签；安装了 [CorpUI](https://github.com/Cerynna/CorpUI)（可选）时，还会在 `/corp` 中加一个页面。

## 须知

- **游戏禁止插件自行在聊天频道发言或发送密语。** 所以通告和密语都通过按钮完成：你的点击发送消息，就像你亲手输入一样。战斗中这些按钮会隐藏。
- **在副本中**，密语内容可能对插件隐藏：请在进本前发送 `!SR`。
- 数据**只与你的公会**通过插件频道共享，不会离开游戏。

## 安装

- **Wago**：[addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr)，用 Wago 应用或手动安装。
- **手动**：把 `CorpSR` 文件夹放到魔兽世界经典版目录的 `Interface\AddOns` 中，然后重启游戏。

## 截图

| | |
|---|---|
| ![积分](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Points.png) | ![历史](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Historique.png) |
| ![活动](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Session.png) | ![待交付](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Remise.png) |
| ![设置](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Reglages.png) | ![已知物品](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raids.png) |

截图中的插件为英文界面；游戏内为简体中文。所有窗口的英文和法文图片：[`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images)。这些图片按插件在演示模式下的真实布局绘制。

## 开发

代码结构、详细规则和测试（法语）：[`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md)。
