# Jigurujingania Bot
### Powered by Razel Tech | Version v1
**High-Frequency XAUUSD M1 Adaptive Recovery Engine & Website Ecosystem**

---

## 1. Quick CLI Compilation Command (MQ5 to EX5)
You can compile `Jigurujingania_Bot_PDVR.mq5` into `Jigurujingania_Bot_PDVR.ex5` at any time without opening the MetaEditor GUI by running this command in your terminal:

```cmd
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"d:\webapps\jiguruginganiabot_website\Jigurujingania_Bot_PDVR.mq5"
```

### 1-Click Method:
Double-click [`compile_bot.bat`](file:///d:/webapps/jiguruginganiabot_website/compile_bot.bat) in this folder. It will:
1. Compile `Jigurujingania_Bot_PDVR.mq5` into `.ex5`.
2. Automatically copy the compiled `.ex5` directly into your active MetaTrader 5 `MQL5\Experts\` directory.
3. Automatically copy the 13 audio files from `jig bot\` directly into your MT5 `Sounds\` directory so all sounds play natively!

---

## 2. Branding & Live HUD Specifications
- **Official Name**: `Jigurujingania Bot`
- **Attribution**: `Powered by Razel Tech`
- **Version**: `v1`
- **On-Chart Live HUD**: Displays:
  - Header: `JIGURUJINGANIA BOT v1 - Powered by Razel Tech`
  - Status: Active (e.g. `7 Days Trial Left`) or Expired
  - Account info: Account login number & account mode (`DEMO` or `REAL`)
  - Spread status: Current live spread vs max allowed spread (with `OK` or `HIGH SPREAD` indicator)
  - Audio status: `ENABLED` or `MUTED`
  - Floating P/L: Real-time net profit/loss in dollars (`+$12.50` or `-$4.20`)
  - Real-time Basket stats: Direction, open order count, volume in lots, current recovery level, Volume-Weighted Average Price (VWAP), and dynamic TP target price
  - Emergency loss warning if loss exceeds -$1500.

---

## 3. Strict Backtesting Restriction
- **Strategy Tester Disabled**: The bot is programmed to **NOT run in backtesting** on either live or demo accounts.
- If attached to the Strategy Tester, `OnInit()` immediately returns `INIT_FAILED` with the alert:
  *"Jigurujingania Bot: Backtesting is strictly disabled in Strategy Tester for this version! Run on Live Chart only."*
- Designed strictly for live forward testing on active M1 charts.

---

## 4. Custom Audio Suite (`jig bot` folder)
The bot includes custom voice alerts located in [`jig bot/`](file:///d:/webapps/jiguruginganiabot_website/jig%20bot):

| Trigger Event | Audio File | Description |
| :--- | :--- | :--- |
| **Initial Trade Placed** | `entry placed.wav` | Plays immediately when the first 0.01 lot position triggers |
| **Take Profit Reached** | `tp hit.wav` | Plays when the dynamic VWAP basket target hits and all orders close in profit |
| **Loss &gt; $1500 Alert** | `Timeout.wav` | Plays when total floating basket loss exceeds -$1500 |
| **Level 1 Recovery** | `level 1.wav` | Plays when Level 1 recovery cluster (3 orders) is triggered |
| **Level 2 Recovery** | `level 2.wav` | Plays when Level 2 recovery cluster is triggered |
| **Level 3 Recovery** | `level 3.wav` | Plays when Level 3 recovery cluster is triggered |
| **Level 4 Recovery** | `level 4.wav` | Plays when Level 4 recovery cluster is triggered |
| **Level 5 Recovery** | `level 5.wav` | Plays when Level 5 recovery cluster is triggered |
| **Level 6 Recovery** | `level 6.wav` | Plays when Level 6 recovery cluster is triggered |
| **Level 7 Recovery** | `level 7.wav` | Plays when Level 7 recovery cluster is triggered |
| **Level 8 Recovery** | `level 8.wav` | Plays when Level 8 recovery cluster is triggered |
| **Level 9 Recovery** | `level 9.wav` | Plays when Level 9 recovery cluster is triggered |
| **Level 10 Recovery** | `level 10.wav` | Plays when Level 10 (Maximum recovery tier) is triggered |

---

## 5. Zero-Leak Dual-Repository Architecture

To guarantee your proprietary strategies and `.mq5` source code are **never leaked**, this project separates your code into two repositories:

| Repository | Purpose | Visibility | Contents |
| :--- | :--- | :--- | :--- |
| **Private Repo** | Development Source of Truth | **Private** | `Jigurujingania_Bot_PDVR.mq5`, scripts, batch files, full dev history |
| **Public Repo** | GitHub Pages Hosting | **Public** | `index.html`, `Jigurujingania_Bot_PDVR.ex5`, `jig bot/` audio, assets (strictly NO `.mq5`) |

### How to Initialize & Link Your Two Repositories:

#### Step A: Link your Private Source Repo (in this folder):
```bash
# In d:\webapps\jiguruginganiabot_website:
git remote add origin https://github.com/YOUR_USERNAME/jigurujingania-private.git
git branch -M main
git push -u origin main
```

#### Step B: Link your Public GitHub Pages Repo:
1. On GitHub, create a new public repository (e.g. `jigurugingania-bot`).
2. Go to **Settings** > **Pages** > Set Source to **Deploy from a branch** > Branch: **`main`** / Folder: **`/ (root)`**.
3. Link the `public_pages` directory to this repository:
```bash
cd public_pages
git remote add origin https://github.com/YOUR_USERNAME/jigurugingania-bot.git
git branch -M main
git push -u origin main
cd ..
```

---

## 6. 1-Click Dual Deploy Command
Whenever you make changes to either the bot or the website, you do **not** need to manually push two repositories. Simply run:

```powershell
.\deploy.ps1 "Your commit message here"
```
Or double-click [`deploy.bat`](file:///d:/webapps/jiguruginganiabot_website/deploy.bat).

### What the deploy script does automatically:
1. Compiles the `.mq5` into `.ex5` using MetaEditor.
2. Copies only the public files (`index.html`, `.ex5`, `jig bot/` audio) into `public_pages/`.
3. Commits and pushes the complete source to your **Private GitHub Repo**.
4. Commits and pushes the website to your **Public GitHub Pages Repo**.
5. Leaves **ZERO trace** of `.mq5` in the public repository!
