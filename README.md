# Jigurujingania Bot by PDVR [Powered by Razel Tech]
### Professional XAUUSD M1 Adaptive Recovery Engine & Website Ecosystem

---

## 1. Quick CLI Compilation Command (MQ5 to EX5)
You can compile `Jigurujingania_Bot_PDVR.mq5` into `Jigurujingania_Bot_PDVR.ex5` at any time without opening the MetaEditor GUI by running this command in your terminal:

```cmd
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"d:\webapps\jiguruginganiabot_website\Jigurujingania_Bot_PDVR.mq5"
```

### Even Easier (1-Click Method):
Double-click [`compile_bot.bat`](file:///d:/webapps/jiguruginganiabot_website/compile_bot.bat) in this folder. It will:
1. Compile `Jigurujingania_Bot_PDVR.mq5` into `.ex5`.
2. Automatically copy the newly generated `.ex5` directly into your active MetaTrader 5 `MQL5\Experts\` directory so it's instantly available in your MT5 terminal!

---

## 2. Zero-Leak Dual-Repository Architecture

To guarantee your proprietary strategies and `.mq5` source code are **never leaked**, this project separates your code into two repositories:

| Repository | Purpose | Visibility | Contents |
| :--- | :--- | :--- | :--- |
| **Private Repo** | Development Source of Truth | **Private** | `Jigurujingania_Bot_PDVR.mq5`, scripts, batch files, full dev history |
| **Public Repo** | GitHub Pages Hosting | **Public** | `index.html`, `Jigurujingania_Bot_PDVR.ex5`, assets (strictly NO `.mq5`) |

### How to Initialize & Link Your Two Repositories:

#### Step A: Link your Private Source Repo (in this folder):
```bash
# In d:\webapps\jiguruginganiabot_website:
git remote add origin https://github.com/YOUR_USERNAME/jigurugingania-private.git
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

## 3. 1-Click Dual Deploy Command
Whenever you make changes to either the bot or the website, you do **not** need to manually push two repositories. Simply run:

```powershell
.\deploy.ps1 "Your commit message here"
```
Or double-click [`deploy.bat`](file:///d:/webapps/jiguruginganiabot_website/deploy.bat).

### What the deploy script does automatically:
1. Compiles the `.mq5` into `.ex5` using MetaEditor.
2. Copies only the public files (`index.html`, `.ex5`, styles) into `public_pages/`.
3. Commits and pushes the complete source to your **Private GitHub Repo**.
4. Commits and pushes the website to your **Public GitHub Pages Repo**.
5. Leaves **ZERO trace** of `.mq5` in the public repository!

---

## 4. Bot Features & Technical Safeguards
- **Branding**: Jigurujingania bot by PDVR | Powered by Razel Tech.
- **Server-Time Verified Trial Protection**:
  - Broker server time (`TimeTradeServer()`) prevents users from bypassing the 3-day or 7-day trial by changing their Windows clock.
  - Beta testing safety switch `InpDemoOnly` forces testers to run on demo accounts during the public trial phase.
- **Audio Sound Alerts**:
  - `InpSoundEntry` ("expert.wav") on initial trade execution.
  - `InpSoundRecovery` ("alert2.wav") on staggered cluster recovery levels.
  - `InpSoundExit` ("ok.wav") on VWAP basket target closure in profit.
  - `InpSoundAlert` ("timeout.wav") on trial expiration or broker spread violation.
- **On-Chart Live HUD Dashboard**: Real-time display of active trial days remaining, spread status, open recovery levels, VWAP, and floating P/L.
