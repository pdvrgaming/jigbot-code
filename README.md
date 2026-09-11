# Jig Bot
### Powered by Razel Tech | Version v1
**High-Frequency XAUUSD M1 Adaptive Recovery Engine & Website Ecosystem**

---

## 1. Quick CLI Compilation & Management (`jigbot.exe` / `jigbot.py`)

No batch (`.bat`) files are used to prevent any Windows OS path corruption. A dedicated native CLI executable [`jigbot.exe`](file:///d:/webapps/jiguruginganiabot_website/jigbot.exe) (and Python CLI [`jigbot.py`](file:///d:/webapps/jiguruginganiabot_website/jigbot.py)) safely handles compilation, MT5 folder synchronization, key generation, and dual-repo deployment without altering your system PATH or environment variables.

### Compile & Sync to MetaTrader 5:
Run this command in your terminal:

```cmd
.\jigbot.exe compile
```
*(Or if using Python: `python jigbot.py compile`)*

**What this does automatically:**
1. Compiles `jig_bot.mq5` into `jig_bot.ex5` via MetaEditor 64.
2. Automatically copies `jig_bot.ex5` into your active MetaTrader 5 `MQL5\Experts\` directory.
3. Automatically copies all 13 voice alerts from `jig bot\` into your MT5 `Sounds\` directory.
4. Leaves your OS PATH and environment completely untouched.

---

## 2. Linked GitHub Repositories (Version Control & Zero Code Leak)

This project is linked to two separate GitHub repositories to ensure that your proprietary `.mq5` source code and strategies are never leaked:

| Repository | GitHub URL | Visibility | Purpose & Contents |
| :--- | :--- | :--- | :--- |
| **Private Code Repo** | [`https://github.com/pdvrgaming/jigbot-code.git`](https://github.com/pdvrgaming/jigbot-code.git) | **Private** | Holds complete source of truth: `jig_bot.mq5`, `src/`, `jigbot.exe`, `jigbot.py`, `license_generator.html`, and full development history. |
| **Public Release Repo** | [`https://github.com/pdvrgaming/jigbot-release.git`](https://github.com/pdvrgaming/jigbot-release.git) | **Public** | Hosted via GitHub Pages: holds only `index.html`, `jig_bot.ex5` binary, and `jig bot/` audio tracks. Strictly **ZERO `.mq5` or private tools**. |

---

## 3. 1-Command Automated Dual Deployment

Whenever you update the bot code or website, you do not need to manually push to two repositories. Simply run:

```cmd
.\jigbot.exe deploy "Your update message here"
```
*(Or with PowerShell: `.\deploy.ps1 "Your message"` | Or with Python: `python jigbot.py deploy "Your message"`)*

### What the deployment command does:
1. Compiles `jig_bot.mq5` to `jig_bot.ex5` and validates zero compilation errors.
2. Mirrors only public release files (`index.html`, `jig_bot.ex5`, `jig bot\` audio) into `public_pages/`.
3. Commits and pushes the complete source to **`jigbot-code`** (`main` branch).
4. Commits and pushes the website & binaries to **`jigbot-release`** (`main` branch).
5. Protected by strict zero-leak `.gitignore` rules.

### Check Repository & Git Status Anytime:
```cmd
.\jigbot.exe status
```

---

## 4. Dual-Tier Cryptographic License Key System & Client Database

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

## 5. Where Does Trader License Data Store? (Private Client Database)

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

### Fast CLI Key Generation:
You can also generate keys directly from your terminal:
```cmd
.\jigbot.exe key 12345678 DEMO 7
```
*(Generates the key, expiry date, and ready-to-send trader instruction message!)*

---

## 6. Telegram Bot & Channel Integration

### A. What to configure in `index.html`:
In [`index.html`](file:///d:/webapps/jiguruginganiabot_website/index.html) at line 125, update the `CONFIG` block:
```javascript
const CONFIG = {
    BOT_NAME: "Jig Bot",
    POWERED_BY: "Razel Tech",
    VERSION: "v1",
    DRIVE_DOWNLOAD_URL: "https://drive.google.com/drive/folders/YOUR_DRIVE_FOLDER_ID_HERE",
    DIRECT_EX5_FILENAME: "jig_bot.ex5",
    TELEGRAM_CHANNEL_URL: "https://t.me/YourChannelName",
    TELEGRAM_SUPPORT_URL: "https://t.me/YourTelegramSupport",
    CONTACT_EMAIL: "support@razeltech.com",
    TRIAL_DAYS: "3, 5, or 7 Days Free Testing Trial",
    RECOMMENDED_SYMBOL: "XAUUSD (Gold)",
    RECOMMENDED_TIMEFRAME: "M1 (1-Minute)"
};
```

---

## 7. Custom Audio Suite (`jig bot` folder)
The bot includes custom voice alerts located in [`jig bot/`](file:///d:/webapps/jiguruginganiabot_website/jig%20bot):

| Trigger Event | Audio File | Description |
| :--- | :--- | :--- |
| **Initial Trade Placed** | `entry placed.wav` | Plays immediately when the first 0.01 lot position triggers |
| **Take Profit Reached** | `tp hit.wav` | Plays when dynamic VWAP basket target hits and all orders close in profit |
| **Loss &gt; $1500 Alert** | `Timeout.wav` | Plays when total floating basket loss exceeds -$1500 |
| **Levels 1 to 10 Recovery** | `level 1.wav` ... `level 10.wav` | Plays when recovery cluster orders are triggered for each level |
