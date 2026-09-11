using System;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace JigBot
{
    class Program
    {
        const string SECRET_SALT = "RAZEL_JIG_BOT_SEC_2026_x9K!";
        const string BOT_MQ5_NAME = "jig_bot.mq5";
        const string BOT_EX5_NAME = "jig_bot.ex5";
        const string PUBLIC_DIR_NAME = "public_pages";

        static string RootDir
        {
            get { return AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
        }

        static int Main(string[] args)
        {
            Console.OutputEncoding = Encoding.UTF8;

            if (args.Length == 0)
            {
                PrintHelp();
                return 0;
            }

            string command = args[0].ToLowerInvariant().Trim();

            switch (command)
            {
                case "compile":
                    return CompileBot();

                case "sync":
                    return SyncPublic();

                case "deploy":
                    string msg = args.Length > 1 ? string.Join(" ", args, 1, args.Length - 1) : "Update Jig Bot and Website " + DateTime.Now.ToString("yyyy-MM-dd HH:mm");
                    return DeployAll(msg);

                case "status":
                    return ShowStatus();

                case "key":
                    if (args.Length < 2)
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("Error: Missing MT5 Account Number.");
                        Console.ResetColor();
                        Console.WriteLine("Usage: jigbot key <ACCOUNT_ID> [DEMO|LIVE] [DAYS]");
                        return 1;
                    }
                    string account = args[1].Trim();
                    string tier = args.Length > 2 ? args[2].ToUpperInvariant() : "DEMO";
                    int days = 7;
                    if (args.Length > 3) int.TryParse(args[3], out days);
                    if (days <= 0) days = (tier == "DEMO") ? 7 : 30;
                    return GenerateKey(account, tier, days);

                case "help":
                case "-h":
                case "--help":
                    PrintHelp();
                    return 0;

                default:
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("Unknown command: " + command);
                    Console.ResetColor();
                    PrintHelp();
                    return 1;
            }
        }

        static void PrintHelp()
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("======================================================================");
            Console.WriteLine("  JIG BOT CLI - SECURE COMPILER & DEPLOYMENT TOOL");
            Console.WriteLine("  Powered by Razel Tech | Version v1");
            Console.WriteLine("======================================================================");
            Console.ResetColor();
            Console.WriteLine("\nCommands:");
            Console.WriteLine("  jigbot compile                 Compile jig_bot.mq5 into jig_bot.ex5 & sync to MT5");
            Console.WriteLine("  jigbot sync                    Mirror public assets into public_pages/ (zero .mq5)");
            Console.WriteLine("  jigbot deploy [commit_message] Compile, sync, commit, and push both code & release repos");
            Console.WriteLine("  jigbot status                  Show git status and remote URLs for both repos");
            Console.WriteLine("  jigbot key <ACCOUNT> [TIER] [DAYS] Generate cryptographic SHA-256 license key");
            Console.WriteLine("  jigbot help                    Show this help screen\n");
        }

        static int CompileBot()
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[1/3] Compiling " + BOT_MQ5_NAME + " to EX5...");
            Console.ResetColor();

            string mq5Path = Path.Combine(RootDir, BOT_MQ5_NAME);
            string ex5Path = Path.Combine(RootDir, BOT_EX5_NAME);

            if (!File.Exists(mq5Path))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Error: Source file not found at " + mq5Path);
                Console.ResetColor();
                return 1;
            }

            string metaEditor = @"C:\Program Files\MetaTrader 5\metaeditor64.exe";
            if (!File.Exists(metaEditor))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Error: MetaEditor not found at " + metaEditor);
                Console.ResetColor();
                return 1;
            }

            // Remove existing ex5 to be 100% sure we verify new compile
            if (File.Exists(ex5Path))
            {
                try { File.Delete(ex5Path); } catch { }
            }

            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = metaEditor,
                Arguments = "/compile:\"" + mq5Path + "\"",
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (Process proc = Process.Start(psi))
            {
                proc.WaitForExit();
            }

            System.Threading.Thread.Sleep(1500);

            if (!File.Exists(ex5Path))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("[FAILED] jig_bot.ex5 was not generated. Check MQL5 compile errors.");
                Console.ResetColor();
                return 1;
            }

            FileInfo fi = new FileInfo(ex5Path);
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("[SUCCESS] " + BOT_EX5_NAME + " compiled successfully! (" + fi.Length + " bytes)");
            Console.ResetColor();

            // Sync to MT5 Experts and Sounds
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[2/3] Syncing binary & audio to MT5 Data Folder...");
            Console.ResetColor();

            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string terminalBase = Path.Combine(appData, @"MetaQuotes\Terminal");

            int syncedCount = 0;
            if (Directory.Exists(terminalBase))
            {
                string[] terminalDirs = Directory.GetDirectories(terminalBase);
                foreach (string tDir in terminalDirs)
                {
                    string mql5Dir = Path.Combine(tDir, "MQL5");
                    if (Directory.Exists(mql5Dir))
                    {
                        string expertsDir = Path.Combine(mql5Dir, "Experts");
                        if (!Directory.Exists(expertsDir)) Directory.CreateDirectory(expertsDir);
                        string destEx5 = Path.Combine(expertsDir, BOT_EX5_NAME);
                        File.Copy(ex5Path, destEx5, true);
                        Console.WriteLine("  -> Synced EX5 to " + expertsDir);

                        // Sync audio
                        string soundsDir = Path.Combine(tDir, "Sounds");
                        if (!Directory.Exists(soundsDir)) Directory.CreateDirectory(soundsDir);
                        string audioSourceDir = Path.Combine(RootDir, "jig bot");
                        if (Directory.Exists(audioSourceDir))
                        {
                            string[] wavs = Directory.GetFiles(audioSourceDir, "*.wav");
                            foreach (string w in wavs)
                            {
                                string wDest = Path.Combine(soundsDir, Path.GetFileName(w));
                                File.Copy(w, wDest, true);
                            }
                            Console.WriteLine("  -> Synced " + wavs.Length + " audio files to " + soundsDir);
                        }
                        syncedCount++;
                    }
                }
            }

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("[3/3] MT5 Sync Complete (" + syncedCount + " terminal profile(s) updated).");
            Console.ResetColor();
            return 0;
        }

        static int SyncPublic()
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\nSyncing public assets to " + PUBLIC_DIR_NAME + "/ (Zero .mq5 leak protection)...");
            Console.ResetColor();

            string publicDir = Path.Combine(RootDir, PUBLIC_DIR_NAME);
            if (!Directory.Exists(publicDir)) Directory.CreateDirectory(publicDir);

            // Clean obsolete ex5 files
            string[] oldEx5s = Directory.GetFiles(publicDir, "*.ex5");
            foreach (string f in oldEx5s)
            {
                if (Path.GetFileName(f).ToLowerInvariant() != BOT_EX5_NAME)
                {
                    try { File.Delete(f); } catch { }
                }
            }

            // Copy index.html
            string srcIndex = Path.Combine(RootDir, "index.html");
            if (File.Exists(srcIndex))
            {
                File.Copy(srcIndex, Path.Combine(publicDir, "index.html"), true);
                Console.WriteLine("  -> Synced index.html");
            }

            // Copy jig_bot.ex5
            string srcEx5 = Path.Combine(RootDir, BOT_EX5_NAME);
            if (File.Exists(srcEx5))
            {
                File.Copy(srcEx5, Path.Combine(publicDir, BOT_EX5_NAME), true);
                Console.WriteLine("  -> Synced " + BOT_EX5_NAME);
            }

            // Copy audio
            string srcAudio = Path.Combine(RootDir, "jig bot");
            string pubAudio = Path.Combine(publicDir, "jig bot");
            if (Directory.Exists(srcAudio))
            {
                if (!Directory.Exists(pubAudio)) Directory.CreateDirectory(pubAudio);
                string[] wavs = Directory.GetFiles(srcAudio, "*.wav");
                foreach (string w in wavs)
                {
                    File.Copy(w, Path.Combine(pubAudio, Path.GetFileName(w)), true);
                }
                Console.WriteLine("  -> Synced " + wavs.Length + " audio tracks to " + PUBLIC_DIR_NAME + @"\jig bot\");
            }

            // Write strict .gitignore in public_pages
            string gitIgnoreContent = 
                "# ZERO-LEAK SECURITY: Strict block on all source code files & private tools\n" +
                "*.mq5\n*.mq4\n*.mqh\n*.cpp\n*.h\n*.log\n*.py\n*.cs\n*.exe\nlicense_generator.html\n";
            File.WriteAllText(Path.Combine(publicDir, ".gitignore"), gitIgnoreContent, Encoding.UTF8);

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("[OK] Public assets successfully synced.");
            Console.ResetColor();
            return 0;
        }

        static int DeployAll(string commitMsg)
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("======================================================================");
            Console.WriteLine("  JIG BOT - AUTOMATED DUAL-REPOSITORY DEPLOYMENT");
            Console.WriteLine("======================================================================");
            Console.ResetColor();

            // 1. Compile
            int cResult = CompileBot();
            if (cResult != 0) return cResult;

            // 2. Sync public
            SyncPublic();

            // 3. Commit and push private repo (jigbot-code)
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[1/2] Processing Private Source Repository (jigbot-code)...");
            Console.ResetColor();

            RunGit(RootDir, "add -A");
            string status = RunGitWithOutput(RootDir, "status --porcelain");
            if (!string.IsNullOrEmpty(status))
            {
                RunGit(RootDir, "commit -m \"" + commitMsg.Replace("\"", "\\\"") + "\"");
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  -> Committed changes to private repo.");
                Console.ResetColor();
            }
            else
            {
                Console.WriteLine("  -> No new changes in private repo.");
            }

            string remotes = RunGitWithOutput(RootDir, "remote");
            if (remotes.Contains("origin"))
            {
                Console.WriteLine("  -> Pushing to origin main (jigbot-code)...");
                RunGit(RootDir, "push origin main");
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.DarkYellow;
                Console.WriteLine("  [NOTE] Set remote with: git remote add origin https://github.com/pdvrgaming/jigbot-code.git");
                Console.ResetColor();
            }

            // 4. Commit and push public repo (jigbot-release)
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\n[2/2] Processing Public Release Repository (jigbot-release)...");
            Console.ResetColor();

            string publicDir = Path.Combine(RootDir, PUBLIC_DIR_NAME);
            if (!Directory.Exists(Path.Combine(publicDir, ".git")))
            {
                RunGit(publicDir, "init -b main");
            }

            RunGit(publicDir, "add -A");
            string pubStatus = RunGitWithOutput(publicDir, "status --porcelain");
            if (!string.IsNullOrEmpty(pubStatus))
            {
                RunGit(publicDir, "commit -m \"" + commitMsg.Replace("\"", "\\\"") + "\"");
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  -> Committed release changes to public repo.");
                Console.ResetColor();
            }
            else
            {
                Console.WriteLine("  -> No new changes in public repo.");
            }

            string pubRemotes = RunGitWithOutput(publicDir, "remote");
            if (pubRemotes.Contains("origin"))
            {
                Console.WriteLine("  -> Pushing to origin main (jigbot-release)...");
                RunGit(publicDir, "push origin main");
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.DarkYellow;
                Console.WriteLine("  [NOTE] Set remote in public_pages with: git remote add origin https://github.com/pdvrgaming/jigbot-release.git");
                Console.ResetColor();
            }

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n======================================================================");
            Console.WriteLine("  DEPLOYMENT SYNC COMPLETE!");
            Console.WriteLine("======================================================================\n");
            Console.ResetColor();
            return 0;
        }

        static int ShowStatus()
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("=== JIG BOT REPOSITORY STATUS ===");
            Console.ResetColor();

            Console.WriteLine("\n[Private Code Repo] " + RootDir);
            Console.WriteLine("Remotes:");
            Console.WriteLine(RunGitWithOutput(RootDir, "remote -v"));
            Console.WriteLine("Branch:");
            Console.WriteLine(RunGitWithOutput(RootDir, "branch"));
            Console.WriteLine("Git Status:");
            Console.WriteLine(RunGitWithOutput(RootDir, "status -s"));

            string publicDir = Path.Combine(RootDir, PUBLIC_DIR_NAME);
            Console.WriteLine("\n--------------------------------------------------");
            Console.WriteLine("[Public Release Repo] " + publicDir);
            if (Directory.Exists(Path.Combine(publicDir, ".git")))
            {
                Console.WriteLine("Remotes:");
                Console.WriteLine(RunGitWithOutput(publicDir, "remote -v"));
                Console.WriteLine("Branch:");
                Console.WriteLine(RunGitWithOutput(publicDir, "branch"));
                Console.WriteLine("Git Status:");
                Console.WriteLine(RunGitWithOutput(publicDir, "status -s"));
            }
            else
            {
                Console.WriteLine("Not initialized as git repo yet.");
            }
            return 0;
        }

        static int GenerateKey(string accountId, string tier, int days)
        {
            DateTime expiry = DateTime.UtcNow.Date.AddDays(days);
            string expiryStr = expiry.ToString("yyyyMMdd");

            string raw = tier + ":" + accountId + ":" + expiryStr + ":" + SECRET_SALT;
            byte[] bytes = Encoding.UTF8.GetBytes(raw);
            byte[] hash;
            using (SHA256 sha = SHA256.Create())
            {
                hash = sha.ComputeHash(bytes);
            }

            string sig = string.Format("{0:X2}{1:X2}{2:X2}{3:X2}", hash[0], hash[1], hash[2], hash[3]);
            string fullKey = "JIG-" + tier + "-" + accountId + "-" + expiryStr + "-" + sig;

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n======================================================================");
            Console.WriteLine("  JIG BOT ACTIVATION KEY GENERATED");
            Console.WriteLine("======================================================================");
            Console.ResetColor();
            Console.WriteLine("Account ID:  #" + accountId);
            Console.WriteLine("License Tier: " + tier + (tier == "DEMO" ? " (Free Trial)" : " (Live Production)"));
            Console.WriteLine("Expiry Date:  " + expiry.ToString("yyyy.MM.dd") + " (" + days + " Days)");
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("\nKey: " + fullKey);
            Console.ResetColor();
            Console.WriteLine("\nTrader Activation Message:\n");
            Console.WriteLine("----------------------------------------------------------------------");
            Console.WriteLine("Hello! Here is your official activation key for Jig Bot v1:\n");
            Console.WriteLine("License Key: " + fullKey + "\n");
            Console.WriteLine("Account: #" + accountId + " (" + (tier == "DEMO" ? "Demo Trial" : "Live Account") + ")");
            Console.WriteLine("Duration: " + days + " Days (Valid until " + expiry.ToString("yyyy.MM.dd") + ")\n");
            Console.WriteLine("How to Activate in MetaTrader 5:");
            Console.WriteLine("1. Attach jig_bot to your XAUUSD M1 chart.");
            Console.WriteLine("2. Press F7 (Properties) -> Inputs.");
            Console.WriteLine("3. Paste the key into InpLicenseKey and click OK.");
            Console.WriteLine("\nNeed assistance? Contact @pdvr_gold_signals_bot or join t.me/PDVR_gold_signals");
            Console.WriteLine("----------------------------------------------------------------------\n");

            return 0;
        }

        static void RunGit(string workDir, string arguments)
        {
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "git",
                Arguments = arguments,
                WorkingDirectory = workDir,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using (Process proc = Process.Start(psi))
            {
                proc.WaitForExit();
            }
        }

        static string RunGitWithOutput(string workDir, string arguments)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "git",
                    Arguments = arguments,
                    WorkingDirectory = workDir,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                };
                using (Process proc = Process.Start(psi))
                {
                    string outText = proc.StandardOutput.ReadToEnd();
                    proc.WaitForExit();
                    return outText.Trim();
                }
            }
            catch (Exception ex)
            {
                return "Error running git: " + ex.Message;
            }
        }
    }
}
