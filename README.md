# Jig Bot
### Powered by Razel Tech | Version v1
**High-Frequency XAUUSD M1 Adaptive Recovery Engine & Website Ecosystem**

---

## 1. Quick CLI Compilation Command (MQ5 to EX5)
You can compile `jig_bot.mq5` into `jig_bot.ex5` at any time without opening the MetaEditor GUI by running this command in your terminal:

```cmd
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"d:\webapps\jiguruginganiabot_website\jig_bot.mq5"
```

### 1-Click Method:
Double-click [`compile_bot.bat`](file:///d:/webapps/jiguruginganiabot_website/compile_bot.bat) in this folder. It will:
1. Compile `jig_bot.mq5` into `jig_bot.ex5`.
2. Automatically copy `jig_bot.ex5` directly into your active MetaTrader 5 `MQL5\Experts\` directory.
3. Automatically copy all 13 audio files from `jig bot\` directly into your MT5 `Sounds\` directory so all voice alerts work natively on chart!

---

## 2. Dual-Tier Cryptographic License Key System & Client Database

Jig Bot uses an **offline, account-bound cryptographic license key system** that prevents unauthorized usage and account sharing without requiring any online web server or MT5 WebRequest configurations.

### Key Format:
```
JIG-<TIER>-<ACCOUNT_ID>-<EXPIRY_YYYYMMDD>-<SIGNATURE>
```

| Tier | Key Prefix | Permissions & Enforcements |
| :--- | :--- | :--- |
| **Demo Trial** | `JIG-DEMO-...` | Valid for **3, 5, or 7 Days** (or custom). **Strictly blocked on Live accounts** (`AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL`). If a user attempts to run a Demo key on a real account, the bot immediately locks. |
| **Live Account** | `JIG-LIVE-...` | Valid for **1 Month (30 Days)**, 3 Months, or Lifetime. Authorized for real money capital trading on MT5. |

### Anti-Piracy & Anti-Tamper Protection:
- **Bound to MT5 Account ID**: The MT5 terminal hardware checks `AccountInfoInteger(ACCOUNT_LOGIN)`. A key generated for account `12345678` **cannot be shared** or run on account `87654321`.
- **Cryptographic Signature**: Signature is computed using `SHA-256(TIER + ":" + ACCOUNT + ":" + EXPIRY + ":" + SECRET_SALT)`. If a user attempts to modify `DEMO` to `LIVE` or alter the expiry date, the signature check fails immediately and trading is locked.
- **Secret Developer Salt**: `RAZEL_JIG_BOT_SEC_2026_x9K!` (embedded inside `jig_bot.mq5`).

---

## 3. Where Does Trader License Data Store? (Private Client Database)

Inside [`license_generator.html`](file:///d:/webapps/jiguruginganiabot_website/license_generator.html), a full **Client License Database** is built-in:

1. **Automatic Local Storage**: Every time you generate a key for a trader, the system automatically saves a record in your browser's private `localStorage` (`jig_bot_license_records_v1`):
   - MT5 Account Number
   - Trader Name / Telegram Handle
   - License Tier (Demo Trial or Live Pro)
   - Duration & Expiry Date
   - Created Date
   - Exact License Key
   - Real-time Active / Expired status
2. **Instant Search & Filters**: Search across all issued licenses by Account #, Trader Name, or Key, or filter by Active / Expired / Demo / Live.
3. **📥 Export to CSV / Excel**: Click the **"Export to CSV / Excel"** button to instantly download a spreadsheet file (`jig_bot_licenses_YYYY-MM-DD.csv`). You can open it in Microsoft Excel, Google Sheets, or keep it as an offline customer CRM record.
4. **📤 Backup & Restore (JSON)**: Easily download a complete JSON database backup or restore your customer records when switching to another computer.
5. **100% Offline & Private**: Zero cloud dependency. Trader account numbers and generated keys never touch any external server.

---

## 4. Telegram Bot & Channel Integration

You asked: *"we have a telegram bot channel also (do i have to provide anything)?"*

### A. What you need to provide for the website & bot:
1. **Telegram Channel Link / Handle**: e.g., `https://t.me/YourChannelName`
2. **Telegram Support / Bot Username**: e.g., `https://t.me/YourBotName` or `@YourSupportHandle`

### B. Where it connects:
- **Website Header & CTAs** ([`index.html`](file:///d:/webapps/jiguruginganiabot_website/index.html)): Traders click the buttons to join your Telegram Channel and request their free 3/5/7-day trial keys. Simply update `CONFIG.TELEGRAM_CHANNEL_URL` and `CONFIG.TELEGRAM_SUPPORT_URL` at the top of `index.html`.
- **On-Chart MT5 HUD** ([`jig_bot.mq5`](file:///d:/webapps/jiguruginganiabot_website/jig_bot.mq5)): When an unactivated bot is attached to an MT5 chart, the HUD displays instructions directing the trader to your Telegram channel/support handle to obtain their activation key.

### C. Optional Automated Key Dispenser (24/7 Telegram Bot):
If you want your Telegram bot to automatically generate and issue 3-day or 7-day demo trial keys to users when they send `/trial <MT5_ACCOUNT_NUMBER>`, you can run a lightweight bot script (Node.js or Python) that runs the exact same SHA-256 algorithm with your secret salt.

---

## 5. Branding & Live HUD Specifications
- **Official Name**: `Jig Bot`
- **Attribution**: `Powered by Razel Tech`
- **Version**: `v1`
- **On-Chart Live HUD**:
  - **When Unlicensed / Locked**: Displays a red warning screen with the active Account ID and instructions to contact Razel Tech support for an activation key.
  - **When Active**: Displays green `ACTIVE` status with:
    - License Tier: `DEMO TRIAL` or `LIVE PRO`
    - Remaining Trial / Access Days countdown
    - Account ID & Mode: `#12345678 (DEMO / REAL - LICENSED)`
    - Spread status: Current live spread vs max allowed spread (`OK` or `HIGH SPREAD`)
    - Audio status: `ENABLED` or `MUTED`
    - Live Basket stats: Direction, open orders count, volume in lots, recovery level (`0` to `10`), VWAP price, unified TP target, and net floating P/L.
    - Emergency loss warning if loss exceeds -$1,500.

---

## 6. Strict Backtesting Restriction
- **Strategy Tester Disabled**: The bot is programmed to **NOT run in backtesting** on either live or demo accounts.
- If attached to the Strategy Tester, `OnInit()` immediately returns `INIT_FAILED` with the alert:
  *"Jig Bot: Backtesting is strictly disabled in Strategy Tester for this version! Run on Live Chart only."*
- Designed strictly for live forward testing on active M1 charts.

---

## 7. Custom Audio Suite (`jig bot` folder)
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

## 8. Zero-Leak Dual-Repository Architecture

To guarantee your proprietary strategies and `.mq5` source code are **never leaked**, this project separates your code into two repositories:

| Repository | Purpose | Visibility | Contents |
| :--- | :--- | :--- | :--- |
| **Private Repo** | Development Source of Truth | **Private** | `jig_bot.mq5`, scripts, batch files, full dev history |
| **Public Repo** | GitHub Pages Hosting | **Public** | `index.html`, `jig_bot.ex5`, `jig bot/` audio, assets (strictly NO `.mq5`) |

### 1-Click Dual Deploy Command:
Whenever you make changes to either the bot or the website, run:

```powershell
.\deploy.ps1 "Your commit message here"
```
Or double-click [`deploy.bat`](file:///d:/webapps/jiguruginganiabot_website/deploy.bat).

### What the deploy script does automatically:
1. Compiles `jig_bot.mq5` into `jig_bot.ex5` using MetaEditor.
2. Copies only public files (`index.html`, `jig_bot.ex5`, `jig bot/` audio) into `public_pages/`.
3. Commits and pushes the complete source to your **Private GitHub Repo**.
4. Commits and pushes the website to your **Public GitHub Pages Repo**.
5. Leaves **ZERO trace** of `.mq5` or private tools in the public repository!
