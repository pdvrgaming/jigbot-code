#!/usr/bin/env python3
"""
Jig Bot Management & Deployment CLI Tool
Powered by Razel Tech | Version v1
Zero-leak dual-repository architecture & cryptographic licensing
"""

import sys
import os
import shutil
import subprocess
import hashlib
import time
from datetime import datetime, timedelta

SECRET_SALT = "RAZEL_JIG_BOT_SEC_2026_x9K!"
BOT_MQ5_NAME = "jig_bot.mq5"
BOT_EX5_NAME = "jig_bot.ex5"
PUBLIC_DIR_NAME = "public_pages"
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

def print_help():
    print("=" * 70)
    print("  JIG BOT PYTHON CLI - SECURE COMPILER & DEPLOYMENT TOOL")
    print("  Powered by Razel Tech | Version v1")
    print("=" * 70)
    print("\nCommands:")
    print("  python jigbot.py compile                 Compile jig_bot.mq5 into jig_bot.ex5 & sync to MT5")
    print("  python jigbot.py sync                    Mirror public assets into public_pages/ (zero .mq5)")
    print("  python jigbot.py deploy [commit_message] Compile, sync, commit, and push both code & release repos")
    print("  python jigbot.py status                  Show git status and remote URLs for both repos")
    print("  python jigbot.py key <ACCOUNT> [TIER] [DAYS] Generate cryptographic SHA-256 license key")
    print("  python jigbot.py help                    Show this help screen\n")

def compile_bot():
    print(f"\n[1/3] Compiling {BOT_MQ5_NAME} to EX5...")
    mq5_path = os.path.join(ROOT_DIR, BOT_MQ5_NAME)
    ex5_path = os.path.join(ROOT_DIR, BOT_EX5_NAME)

    if not os.path.isfile(mq5_path):
        print(f"Error: Source file not found at {mq5_path}")
        return 1

    meta_editor = r"C:\Program Files\MetaTrader 5\metaeditor64.exe"
    if not os.path.isfile(meta_editor):
        print(f"Error: MetaEditor not found at {meta_editor}")
        return 1

    if os.path.isfile(ex5_path):
        try:
            os.remove(ex5_path)
        except OSError:
            pass

    subprocess.run([meta_editor, f"/compile:{mq5_path}"], check=False)
    time.sleep(1.5)

    if not os.path.isfile(ex5_path):
        print("[FAILED] jig_bot.ex5 was not generated. Check MQL5 compile errors.")
        return 1

    size = os.path.getsize(ex5_path)
    print(f"[SUCCESS] {BOT_EX5_NAME} compiled successfully! ({size} bytes)")

    print("\n[2/3] Syncing binary & audio to MT5 Data Folder...")
    app_data = os.environ.get("APPDATA", "")
    terminal_base = os.path.join(app_data, "MetaQuotes", "Terminal")

    synced_count = 0
    if os.path.isdir(terminal_base):
        for entry in os.listdir(terminal_base):
            t_dir = os.path.join(terminal_base, entry)
            mql5_dir = os.path.join(t_dir, "MQL5")
            if os.path.isdir(mql5_dir):
                experts_dir = os.path.join(mql5_dir, "Experts")
                os.makedirs(experts_dir, exist_ok=True)
                shutil.copy2(ex5_path, os.path.join(experts_dir, BOT_EX5_NAME))
                print(f"  -> Synced EX5 to {experts_dir}")

                sounds_dir = os.path.join(t_dir, "Sounds")
                os.makedirs(sounds_dir, exist_ok=True)
                audio_src = os.path.join(ROOT_DIR, "jig bot")
                if os.path.isdir(audio_src):
                    wavs = [f for f in os.listdir(audio_src) if f.endswith(".wav")]
                    for w in wavs:
                        shutil.copy2(os.path.join(audio_src, w), os.path.join(sounds_dir, w))
                    print(f"  -> Synced {len(wavs)} audio tracks to {sounds_dir}")
                synced_count += 1

    print(f"[3/3] MT5 Sync Complete ({synced_count} terminal profile(s) updated).")
    return 0

def sync_public():
    print(f"\nSyncing public assets to {PUBLIC_DIR_NAME}/ (Zero .mq5 leak protection)...")
    public_dir = os.path.join(ROOT_DIR, PUBLIC_DIR_NAME)
    os.makedirs(public_dir, exist_ok=True)

    # Clean old ex5
    for f in os.listdir(public_dir):
        if f.endswith(".ex5") and f.lower() != BOT_EX5_NAME:
            try:
                os.remove(os.path.join(public_dir, f))
            except OSError:
                pass

    # Copy index.html
    src_index = os.path.join(ROOT_DIR, "index.html")
    if os.path.isfile(src_index):
        shutil.copy2(src_index, os.path.join(public_dir, "index.html"))
        print("  -> Synced index.html")

    # Copy jig_bot.ex5
    src_ex5 = os.path.join(ROOT_DIR, BOT_EX5_NAME)
    if os.path.isfile(src_ex5):
        shutil.copy2(src_ex5, os.path.join(public_dir, BOT_EX5_NAME))
        print(f"  -> Synced {BOT_EX5_NAME}")

    # Copy audio
    src_audio = os.path.join(ROOT_DIR, "jig bot")
    pub_audio = os.path.join(public_dir, "jig bot")
    if os.path.isdir(src_audio):
        os.makedirs(pub_audio, exist_ok=True)
        wavs = [f for f in os.listdir(src_audio) if f.endswith(".wav")]
        for w in wavs:
            shutil.copy2(os.path.join(src_audio, w), os.path.join(pub_audio, w))
        print(f"  -> Synced {len(wavs)} audio tracks to {PUBLIC_DIR_NAME}/jig bot/")

    # Strict .gitignore in public_pages
    gitignore_content = (
        "# ZERO-LEAK SECURITY: Strict block on all source code files & private tools\n"
        "*.mq5\n*.mq4\n*.mqh\n*.cpp\n*.h\n*.log\n*.py\n*.cs\n*.exe\nlicense_generator.html\n"
    )
    with open(os.path.join(public_dir, ".gitignore"), "w", encoding="utf-8") as f:
        f.write(gitignore_content)

    print("[OK] Public assets successfully synced.")
    return 0

def deploy_all(commit_msg):
    print("=" * 70)
    print("  JIG BOT - AUTOMATED DUAL-REPOSITORY DEPLOYMENT")
    print("=" * 70)

    # 1. Compile
    res = compile_bot()
    if res != 0:
        return res

    # 2. Sync public
    sync_public()

    # 3. Commit and push private repo (jigbot-code)
    print("\n[1/2] Processing Private Source Repository (jigbot-code)...")
    subprocess.run(["git", "add", "-A"], cwd=ROOT_DIR)
    status = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT_DIR, capture_output=True, text=True).stdout.strip()
    if status:
        subprocess.run(["git", "commit", "-m", commit_msg], cwd=ROOT_DIR)
        print("  -> Committed changes to private repo.")
    else:
        print("  -> No new changes in private repo.")

    remotes = subprocess.run(["git", "remote"], cwd=ROOT_DIR, capture_output=True, text=True).stdout
    if "origin" in remotes:
        print("  -> Pushing to origin main (jigbot-code)...")
        subprocess.run(["git", "push", "origin", "main"], cwd=ROOT_DIR)
    else:
        print("  [NOTE] Set remote with: git remote add origin https://github.com/pdvrgaming/jigbot-code.git")

    # 4. Commit and push public repo (jigbot-release)
    print("\n[2/2] Processing Public Release Repository (jigbot-release)...")
    public_dir = os.path.join(ROOT_DIR, PUBLIC_DIR_NAME)
    if not os.path.isdir(os.path.join(public_dir, ".git")):
        subprocess.run(["git", "init", "-b", "main"], cwd=public_dir)

    subprocess.run(["git", "add", "-A"], cwd=public_dir)
    pub_status = subprocess.run(["git", "status", "--porcelain"], cwd=public_dir, capture_output=True, text=True).stdout.strip()
    if pub_status:
        subprocess.run(["git", "commit", "-m", commit_msg], cwd=public_dir)
        print("  -> Committed release changes to public repo.")
    else:
        print("  -> No new changes in public repo.")

    pub_remotes = subprocess.run(["git", "remote"], cwd=public_dir, capture_output=True, text=True).stdout
    if "origin" in pub_remotes:
        print("  -> Pushing to origin main (jigbot-release)...")
        subprocess.run(["git", "push", "origin", "main"], cwd=public_dir)
    else:
        print("  [NOTE] Set remote in public_pages with: git remote add origin https://github.com/pdvrgaming/jigbot-release.git")

    print("\n" + "=" * 70)
    print("  DEPLOYMENT SYNC COMPLETE!")
    print("=" * 70 + "\n")
    return 0

def show_status():
    print("=== JIG BOT REPOSITORY STATUS ===")
    print(f"\n[Private Code Repo] {ROOT_DIR}")
    print("Remotes:")
    subprocess.run(["git", "remote", "-v"], cwd=ROOT_DIR)
    print("Branch:")
    subprocess.run(["git", "branch"], cwd=ROOT_DIR)
    print("Git Status:")
    subprocess.run(["git", "status", "-s"], cwd=ROOT_DIR)

    public_dir = os.path.join(ROOT_DIR, PUBLIC_DIR_NAME)
    print("\n--------------------------------------------------")
    print(f"[Public Release Repo] {public_dir}")
    if os.path.isdir(os.path.join(public_dir, ".git")):
        print("Remotes:")
        subprocess.run(["git", "remote", "-v"], cwd=public_dir)
        print("Branch:")
        subprocess.run(["git", "branch"], cwd=public_dir)
        print("Git Status:")
        subprocess.run(["git", "status", "-s"], cwd=public_dir)
    else:
        print("Not initialized as git repo yet.")
    return 0

def generate_key(account_id, tier="DEMO", days=7):
    tier = tier.upper()
    expiry = datetime.utcnow().date() + timedelta(days=days)
    expiry_str = expiry.strftime("%Y%m%d")

    raw_text = f"{tier}:{account_id}:{expiry_str}:{SECRET_SALT}"
    h = hashlib.sha256(raw_text.encode("utf-8")).digest()
    sig = "".join(f"{b:02X}" for b in h[:4])

    full_key = f"JIG-{tier}-{account_id}-{expiry_str}-{sig}"

    print("\n" + "=" * 70)
    print("  JIG BOT ACTIVATION KEY GENERATED")
    print("=" * 70)
    print(f"Account ID:   #{account_id}")
    print(f"License Tier: {tier} ({'Free Trial' if tier == 'DEMO' else 'Live Production'})")
    print(f"Expiry Date:  {expiry.strftime('%Y.%m.%d')} ({days} Days)")
    print(f"\nKey: {full_key}")
    print("\nTrader Activation Message:\n")
    print("-" * 70)
    print(f"Hello! Here is your official activation key for Jig Bot v1:\n")
    print(f"License Key: {full_key}\n")
    print(f"Account: #{account_id} ({'Demo Trial' if tier == 'DEMO' else 'Live Account'})")
    print(f"Duration: {days} Days (Valid until {expiry.strftime('%Y.%m.%d')})\n")
    print("How to Activate in MetaTrader 5:")
    print("1. Attach jig_bot to your XAUUSD M1 chart.")
    print("2. Press F7 (Properties) -> Inputs.")
    print("3. Paste the key into InpLicenseKey and click OK.")
    print("-" * 70 + "\n")
    return 0

def main():
    if len(sys.argv) < 2:
        print_help()
        return 0

    cmd = sys.argv[1].lower().strip()
    if cmd == "compile":
        return compile_bot()
    elif cmd == "sync":
        return sync_public()
    elif cmd == "deploy":
        msg = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else f"Update Jig Bot and Website {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        return deploy_all(msg)
    elif cmd == "status":
        return show_status()
    elif cmd == "key":
        if len(sys.argv) < 3:
            print("Error: Missing MT5 Account Number.")
            print("Usage: python jigbot.py key <ACCOUNT_ID> [DEMO|LIVE] [DAYS]")
            return 1
        account = sys.argv[2].strip()
        tier = sys.argv[3].upper() if len(sys.argv) > 3 else "DEMO"
        days = int(sys.argv[4]) if len(sys.argv) > 4 else (7 if tier == "DEMO" else 30)
        return generate_key(account, tier, days)
    elif cmd in ("help", "-h", "--help"):
        print_help()
        return 0
    else:
        print(f"Unknown command: {cmd}")
        print_help()
        return 1

if __name__ == "__main__":
    sys.exit(main())
