//+------------------------------------------------------------------+
//|                                    Jigurujingania_Bot_PDVR.mq5   |
//|                                      Jigurujingania Bot          |
//|                             Powered by Razel Tech                |
//|                                      https://jugurujingania.bot  |
//+------------------------------------------------------------------+
#property copyright   "Powered by Razel Tech"
#property link        "https://jugurujingania.bot"
#property version     "1.00"
#property description "Jigurujingania Bot - XAUUSD M1 Adaptive Recovery Engine [Powered by Razel Tech]"
#property strict



// Include standard trade libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input Parameters ---
input group "=== 0. LICENSE ACTIVATION ==="
input string   InpLicenseKey            = "";                       // License Key (e.g. JJ-DEMO-12345678-20260918-XXXX or JJ-LIVE-...)
input bool     InpEnableLicenseGuard    = true;                     // Enable License Guard

input group "=== 1. SOUND & AUDIO NOTIFICATIONS ==="
input bool     InpEnableSounds          = true;                     // Enable Sound Alerts
input double   InpTimeoutLossThreshold  = 1500.00;                  // Loss Threshold for Timeout Audio ($)

input group "=== 2. INITIAL TRADE PARAMETERS ==="
input double   InpInitialLot            = 0.01;                     // Initial Lot Size
input double   InpTakeProfitPoints      = 4.20;                     // Initial TP in Points (42 pips in Gold)
input double   InpStopLossPoints        = 0.00;                     // Initial SL in Points (0 = Disabled, relies on recovery grid)
input ulong    InpMagicNumber           = 1223335;                  // Magic Number (Unique ID)
input string   InpTradeComment          = "JJ Bot";                 // Order Comment

input group "=== 3. 3-ORDER CLUSTER RECOVERY GRID ==="
input bool     InpEnableRecovery        = true;                     // Enable Grid Recovery
input double   InpGridStepPoints        = 10.00;                    // Grid Step per Level in Points (10.0 pts)
input int      InpMaxGridLevels         = 10;                       // Max Recovery Levels (1 to 10)
input double   InpBasketTpPoints        = 4.20;                     // Unified Basket TP from VWAP in Points
input bool     InpEnableBasketTrailing  = true;                     // Enable Active Basket Trailing Close
input double   InpBasketTrailStepPoints = 1.00;                     // Trailing Step in Points

input group "=== 4. STAGGERED RECOVERY ORDER TIMING ==="
input int      InpMinOrderDelaySeconds  = 1;                        // Minimum gap between cluster orders
input int      InpMaxOrderDelaySeconds  = 3;                        // Maximum gap between cluster orders
input bool     InpRandomizeOrderDelay   = true;                     // Randomize each gap between min/max

input group "=== 5. ENTRY STRATEGY FILTER ==="
input int      InpConsecutiveBars       = 3;                        // Number of bars for momentum check
input double   InpMinSpikePoints        = 3.00;                     // Minimum price spike movement in points
input int      InpMaxSpreadPoints       = 50;                       // Maximum Allowed Spread (in points)
input ENUM_TIMEFRAMES InpTimeframe      = PERIOD_M1;                // Evaluation Timeframe

//--- Global Objects & State Tracking ---
CTrade         m_trade;
CPositionInfo  m_position;
datetime       m_last_bar_time          = 0;
int            m_current_grid_level     = 0;   // 0 = Initial trade only, 1..10 = recovery cluster active
double         m_initial_price          = 0.0; // Open price of the initial 0.01 trade

//--- Staggered cluster execution state
bool               m_cluster_pending       = false;
int                m_cluster_level         = 0;
ENUM_POSITION_TYPE m_cluster_type          = POSITION_TYPE_BUY;
int                m_cluster_next_order    = 0;
int                m_cluster_success_count = 0;
datetime           m_next_order_time       = 0;
bool               m_had_positions_previous_tick = false;

//--- License Key & Protection Variables
const string       DEVELOPER_SECRET_SALT         = "RAZEL_JJ_BOT_SEC_2026_x9K!";
bool               m_license_active              = false;
string             m_license_tier                = "NONE";      // "DEMO" or "LIVE"
int                m_license_days_left           = 0;
string             m_license_status_msg          = "UNLICENSED";
string             m_license_error_details       = "Enter your activation key in EA Inputs.";
datetime           m_license_expiry_time         = 0;
datetime           m_last_timeout_audio_time     = 0;
datetime           m_last_tphit_audio_time       = 0;

//+------------------------------------------------------------------+
//| Custom Audio Notification Helper with triple-layer fallback      |
//+------------------------------------------------------------------+
void PlayCustomAudio(const string file_name)
{
   if(!InpEnableSounds || StringLen(file_name) == 0)
      return;

   // 1. Play embedded resource
   string resource_path = "::jig bot\\" + file_name;
   if(PlaySound(resource_path))
      return;

   // 2. Play from Sounds\jig bot\ subfolder
   string subfolder_path = "jig bot\\" + file_name;
   if(PlaySound(subfolder_path))
      return;

   // 3. Play from Sounds\ directly
   PlaySound(file_name);
}

//+------------------------------------------------------------------+
//| Play Level Audio for Levels 1 to 10                              |
//+------------------------------------------------------------------+
void PlayLevelAudio(int level)
{
   if(level >= 1 && level <= 10)
   {
      string sound_file = StringFormat("level %d.wav", level);
      PlayCustomAudio(sound_file);
   }
}

//+------------------------------------------------------------------+
//| Calculate Total Floating Basket Profit / Loss in Account Currency|
//+------------------------------------------------------------------+
double GetBasketFloatingProfit()
{
   double total_profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            total_profit += (m_position.Profit() + m_position.Swap());
         }
      }
   }
   return total_profit;
}

//+------------------------------------------------------------------+
//| Check Floating Loss Threshold and Play Timeout Audio             |
//+------------------------------------------------------------------+
void CheckLossTimeoutAlert()
{
   if(InpTimeoutLossThreshold <= 0.0)
      return;

   double floating_profit = GetBasketFloatingProfit();

   // If floating loss exceeds threshold (e.g. loss > 1500$)
   if(floating_profit <= -InpTimeoutLossThreshold)
   {
      datetime now = TimeCurrent();
      // Avoid spamming audio on every microsecond tick; cooldown 30 seconds
      if(now - m_last_timeout_audio_time >= 30)
      {
         m_last_timeout_audio_time = now;
         PrintFormat(">> Jigurujingania Bot ALERT: Floating loss -$%.2f exceeds -$%.2f threshold! Playing Timeout audio...",
                     MathAbs(floating_profit), InpTimeoutLossThreshold);
         PlayCustomAudio("Timeout.wav");
         Alert(StringFormat("Jigurujingania Bot Warning: Floating loss -$%.2f exceeds -$%.2f!", 
                            MathAbs(floating_profit), InpTimeoutLossThreshold));
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate 8-character SHA-256 signature for license key validation|
//+------------------------------------------------------------------+
string CalculateLicenseSignature(const string tier, const long account_id, const string expiry_str)
{
   string raw = StringFormat("%s:%I64d:%s:%s", tier, account_id, expiry_str, DEVELOPER_SECRET_SALT);
   int len = StringLen(raw);
   uchar data[];
   ArrayResize(data, len);
   for(int i = 0; i < len; i++)
      data[i] = (uchar)StringGetCharacter(raw, i);

   uchar key[];
   uchar result[];
   int res = CryptEncode(CRYPT_HASH_SHA256, data, key, result);
   if(res <= 0)
      return "";

   string sig = "";
   for(int i = 0; i < 4; i++) // 4 bytes = 8 hex chars
      sig += StringFormat("%02X", result[i]);

   return sig;
}

//+------------------------------------------------------------------+
//| Validate Account-Bound Dual-Tier License Key                     |
//+------------------------------------------------------------------+
bool ValidateLicenseKey(const string key_str)
{
   if(!InpEnableLicenseGuard)
   {
      m_license_active = true;
      m_license_tier = "BYPASS";
      m_license_days_left = 999;
      m_license_status_msg = "ACTIVE (Guard Disabled)";
      m_license_error_details = "";
      return true;
   }

   string trimmed_key = key_str;
   StringTrimLeft(trimmed_key);
   StringTrimRight(trimmed_key);

   if(StringLen(trimmed_key) == 0)
   {
      m_license_active = false;
      m_license_tier = "NONE";
      m_license_days_left = 0;
      m_license_status_msg = "UNLICENSED (No Key Entered)";
      m_license_error_details = "Enter your activation key in EA Inputs (F7).";
      return false;
   }

   // Expected format: JJ-<TIER>-<ACCOUNT>-<YYYYMMDD>-<SIG>
   string parts[];
   int count = StringSplit(trimmed_key, '-', parts);
   if(count != 5)
   {
      m_license_active = false;
      m_license_tier = "INVALID";
      m_license_days_left = 0;
      m_license_status_msg = "INVALID KEY FORMAT";
      m_license_error_details = "Key must be: JJ-TIER-ACCOUNT-YYYYMMDD-XXXXXXXX";
      return false;
   }

   if(parts[0] != "JJ")
   {
      m_license_active = false;
      m_license_status_msg = "INVALID KEY PREFIX";
      m_license_error_details = "Key must start with 'JJ-'.";
      return false;
   }

   string tier = parts[1];
   StringToUpper(tier);
   if(tier != "DEMO" && tier != "LIVE")
   {
      m_license_active = false;
      m_license_status_msg = "INVALID LICENSE TIER";
      m_license_error_details = "Tier must be DEMO or LIVE.";
      return false;
   }

   long key_account = StringToInteger(parts[2]);
   long active_account = AccountInfoInteger(ACCOUNT_LOGIN);
   if(key_account != active_account)
   {
      m_license_active = false;
      m_license_status_msg = StringFormat("ACCOUNT MISMATCH (Key for #%I64d)", key_account);
      m_license_error_details = StringFormat("Key is for account #%I64d, but active account is #%I64d.", key_account, active_account);
      return false;
   }

   string expiry_str = parts[3];
   if(StringLen(expiry_str) != 8)
   {
      m_license_active = false;
      m_license_status_msg = "INVALID EXPIRY FORMAT";
      m_license_error_details = "Expiry date must be 8 digits (YYYYMMDD).";
      return false;
   }

   string provided_sig = parts[4];
   StringToUpper(provided_sig);
   string expected_sig = CalculateLicenseSignature(tier, active_account, expiry_str);

   if(provided_sig != expected_sig)
   {
      m_license_active = false;
      m_license_status_msg = "INVALID SIGNATURE / TAMPERED KEY";
      m_license_error_details = "Cryptographic signature mismatch! Key is invalid or modified.";
      return false;
   }

   // Strict Demo Account Enforcement
   long trade_mode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(tier == "DEMO" && trade_mode != ACCOUNT_TRADE_MODE_DEMO)
   {
      m_license_active = false;
      m_license_tier = "DEMO";
      m_license_status_msg = "DEMO KEY ON LIVE ACCOUNT (BLOCKED)";
      m_license_error_details = "Demo trial keys cannot be used on Real/Live accounts! Contact Razel Tech for Live Access.";
      return false;
   }

   // Parse expiry date (YYYYMMDD)
   int year  = (int)StringToInteger(StringSubstr(expiry_str, 0, 4));
   int month = (int)StringToInteger(StringSubstr(expiry_str, 4, 2));
   int day   = (int)StringToInteger(StringSubstr(expiry_str, 6, 2));

   MqlDateTime mdt;
   mdt.year = year;
   mdt.mon  = month;
   mdt.day  = day;
   mdt.hour = 23;
   mdt.min  = 59;
   mdt.sec  = 59;

   datetime expiry_datetime = StructToTime(mdt);
   m_license_expiry_time = expiry_datetime;

   datetime current_server_time = TimeTradeServer();
   if(current_server_time == 0)
      current_server_time = TimeCurrent();

   if(current_server_time >= expiry_datetime)
   {
      m_license_active = false;
      m_license_tier = tier;
      m_license_days_left = 0;
      m_license_status_msg = StringFormat("%s LICENSE EXPIRED on %04d.%02d.%02d", tier, year, month, day);
      m_license_error_details = "Access period has ended. Contact Razel Tech to renew your license.";
      return false;
   }

   long remaining_sec = (long)(expiry_datetime - current_server_time);
   int days_left = (int)(remaining_sec / 86400) + 1;

   m_license_active = true;
   m_license_tier = tier;
   m_license_days_left = days_left;
   m_license_status_msg = StringFormat("ACTIVE (%d Days Left)", days_left);
   m_license_error_details = "";

   return true;
}

//+------------------------------------------------------------------+
//| Update On-Chart Live HUD Dashboard (Displays version v1)         |
//+------------------------------------------------------------------+
void UpdateChartDashboard(int open_count, double total_vol, double vwap, ENUM_POSITION_TYPE basket_type)
{
   string account_mode_str = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO) ? "DEMO" : "REAL";
   long login_id = AccountInfoInteger(ACCOUNT_LOGIN);

   if(!m_license_active)
   {
      string locked_hud = StringFormat(
         "=====================================================\n"
         "  JIGURUJINGANIA BOT  v1  [LOCKED]\n"
         "  Powered by Razel Tech\n"
         "=====================================================\n"
         "  License Status: %s\n"
         "  Active Account: #%I64d (%s)\n"
         "  Issue Details:  %s\n"
         "-----------------------------------------------------\n"
         "  ACTIVATION INSTRUCTIONS:\n"
         "  1. Copy your MT5 Account ID: %I64d\n"
         "  2. Request your Activation Key from Razel Tech:\n"
         "     - Demo Trial: 3, 5, or 7-Day Access\n"
         "     - Live Account: 1-Month Pro Access\n"
         "     - Contact: support@jigurujingania.bot\n"
         "  3. Open Bot Inputs (F7) -> Paste into InpLicenseKey\n"
         "=====================================================",
         m_license_status_msg,
         login_id, account_mode_str,
         m_license_error_details,
         login_id
      );
      Comment(locked_hud);
      return;
   }

   // ACTIVE LICENSED DASHBOARD
   long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   string spread_status = StringFormat("%I64d / Max %d pts (%s)", 
                                       current_spread, InpMaxSpreadPoints, 
                                       (current_spread <= InpMaxSpreadPoints ? "OK" : "HIGH SPREAD"));

   double floating_pnl = GetBasketFloatingProfit();

   string basket_info = "No Active Basket (Scanning M1 Candlesticks)";
   if(open_count > 0)
   {
      double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double target_price = (basket_type == POSITION_TYPE_BUY) ? (vwap + InpBasketTpPoints) : (vwap - InpBasketTpPoints);
      
      basket_info = StringFormat("%s Basket | Orders: %d | Lots: %.2f | Level: %d\n"
                                 "  VWAP: %.2f | Target: %.2f | Current: %.2f\n"
                                 "  Floating PnL: %s$%.2f",
                                 (basket_type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                                 open_count, total_vol, m_current_grid_level,
                                 vwap, target_price, (basket_type == POSITION_TYPE_BUY ? current_bid : current_ask),
                                 (floating_pnl >= 0 ? "+" : "-"), MathAbs(floating_pnl));
   }

   string timeout_warning = "";
   if(floating_pnl <= -InpTimeoutLossThreshold)
   {
      timeout_warning = StringFormat("\n  *** WARNING: LOSS EXCEEDS $%.2f (Timeout Alert Active) ***", InpTimeoutLossThreshold);
   }

   string hud = StringFormat(
      "=====================================================\n"
      "  JIGURUJINGANIA BOT  v1  [ACTIVE]\n"
      "  Powered by Razel Tech\n"
      "=====================================================\n"
      "  License Tier:   %s PRO (%d Days Left)\n"
      "  Account:        #%I64d (%s - LICENSED)\n"
      "  Spread Status:  %s\n"
      "  Audio Alerts:   %s\n"
      "-----------------------------------------------------\n"
      "  %s%s\n"
      "=====================================================",
      m_license_tier, m_license_days_left,
      login_id, account_mode_str,
      spread_status,
      (InpEnableSounds ? "ENABLED" : "MUTED"),
      basket_info,
      timeout_warning
   );

   Comment(hud);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. STRICT BACKTESTING RESTRICTION (Disabled in Strategy Tester)
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_VISUAL_MODE))
   {
      string block_msg = "Jigurujingania Bot: Backtesting is strictly disabled in Strategy Tester for this version! Run on Live Chart only.";
      Print(block_msg);
      Alert(block_msg);
      return(INIT_FAILED);
   }

   // 2. Configure CTrade object
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetDeviationInPoints(20);
   MathSrand((uint)(GetTickCount() ^ (uint)TimeLocal()));

   // 3. Perform cryptographic license validation
   if(!ValidateLicenseKey(InpLicenseKey))
   {
      PrintFormat(">> Jigurujingania Bot License Check: %s. %s", m_license_status_msg, m_license_error_details);
      PlayCustomAudio("Timeout.wav");
      UpdateChartDashboard(0, 0, 0, POSITION_TYPE_BUY);
      // Return INIT_SUCCEEDED so HUD remains on chart to display Account ID and activation instructions.
      // All trading is locked in OnTick() while !m_license_active.
      return(INIT_SUCCEEDED);
   }

   PrintFormat("Jigurujingania Bot v1 [Powered by Razel Tech] ACTIVATED for %s Account #%I64d (%d Days Remaining).",
               m_license_tier, AccountInfoInteger(ACCOUNT_LOGIN), m_license_days_left);
   
   UpdateChartDashboard(0, 0, 0, POSITION_TYPE_BUY);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment(""); // Clear on-chart HUD
   PrintFormat("Jigurujingania Bot v1 deinitialized. Reason: %d", reason);
}

//+------------------------------------------------------------------+
//| Check if a new candle has opened on the configured timeframe     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime current_bar_time = iTime(_Symbol, InpTimeframe, 0);
   if(current_bar_time != m_last_bar_time)
   {
      m_last_bar_time = current_bar_time;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calculate Volume-Weighted Average Price (VWAP) for open basket   |
//+------------------------------------------------------------------+
bool GetBasketStats(ENUM_POSITION_TYPE &basket_type, double &vwap, double &total_vol, int &count, double &initial_open_price)
{
   vwap = 0.0;
   total_vol = 0.0;
   count = 0;
   initial_open_price = 0.0;
   double total_weighted_price = 0.0;
   datetime earliest_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            ENUM_POSITION_TYPE p_type = m_position.PositionType();
            double p_vol  = m_position.Volume();
            double p_open = m_position.PriceOpen();
            datetime p_time = (datetime)m_position.Time();

            // Track initial trade (earliest open time)
            if(count == 0 || p_time < earliest_time)
            {
               earliest_time = p_time;
               initial_open_price = p_open;
               basket_type = p_type;
            }

            total_vol += p_vol;
            total_weighted_price += (p_open * p_vol);
            count++;
         }
      }
   }

   if(total_vol > 0.0)
   {
      vwap = total_weighted_price / total_vol;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update all open orders in the basket to a unified Take Profit    |
//+------------------------------------------------------------------+
void UpdateBasketTakeProfit(ENUM_POSITION_TYPE basket_type, double vwap)
{
   double unified_tp = 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(basket_type == POSITION_TYPE_BUY)
      unified_tp = NormalizeDouble(vwap + InpBasketTpPoints, digits);
   else
      unified_tp = NormalizeDouble(vwap - InpBasketTpPoints, digits);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            ulong ticket = m_position.Ticket();
            double current_tp = m_position.TakeProfit();
            double current_sl = m_position.StopLoss();

            // Only modify if TP differs by more than 0.05 points
            if(MathAbs(current_tp - unified_tp) > 0.05)
            {
               if(m_trade.PositionModify(ticket, current_sl, unified_tp))
                  PrintFormat("Updated Ticket #%I64u TP to Unified VWAP TP: %.2f (VWAP: %.2f)", ticket, unified_tp, vwap);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close all open basket positions immediately                      |
//+------------------------------------------------------------------+
void CloseAllBasketPositions()
{
   Print(">> Closing all open basket positions in profit...");
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            ulong ticket = m_position.Ticket();
            m_trade.PositionClose(ticket);
         }
      }
   }
   
   // Play TP HIT sound with cooldown
   datetime now = TimeCurrent();
   if(now - m_last_tphit_audio_time >= 3)
   {
      m_last_tphit_audio_time = now;
      PlayCustomAudio("tp hit.wav");
   }

   m_current_grid_level = 0;
   m_initial_price = 0.0;
}

//+------------------------------------------------------------------+
//| Check basket target and active trailing close                    |
//+------------------------------------------------------------------+
void CheckBasketExit(ENUM_POSITION_TYPE basket_type, double vwap, int count)
{
   // If only initial order is open, broker TP will handle it
   if(count <= 1 || !InpEnableBasketTrailing)
      return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool should_close = false;

   if(basket_type == POSITION_TYPE_BUY)
   {
      double target_price = vwap + InpBasketTpPoints;
      // Close basket if bid reaches or exceeds target price
      if(bid >= target_price)
      {
         PrintFormat(">> BUY Basket Target Reached: Bid=%.2f >= VWAP+TP=%.2f. Closing all %d positions...", 
                     bid, target_price, count);
         should_close = true;
      }
   }
   else if(basket_type == POSITION_TYPE_SELL)
   {
      double target_price = vwap - InpBasketTpPoints;
      // Close basket if ask drops to or below target price
      if(ask <= target_price)
      {
         PrintFormat(">> SELL Basket Target Reached: Ask=%.2f <= VWAP-TP=%.2f. Closing all %d positions...", 
                     ask, target_price, count);
         should_close = true;
      }
   }

   if(should_close)
   {
      CloseAllBasketPositions();
   }
}

//+------------------------------------------------------------------+
//| Reset staggered cluster state                                    |
//+------------------------------------------------------------------+
void ResetClusterState()
{
   m_cluster_pending = false;
   m_cluster_level = 0;
   m_cluster_next_order = 0;
   m_cluster_success_count = 0;
   m_next_order_time = 0;
}

//+------------------------------------------------------------------+
//| Return randomized delay in seconds                               |
//+------------------------------------------------------------------+
int GetOrderDelaySeconds()
{
   int min_delay = MathMax(1, InpMinOrderDelaySeconds);
   int max_delay = MathMax(min_delay, InpMaxOrderDelaySeconds);

   if(!InpRandomizeOrderDelay || min_delay == max_delay)
      return min_delay;

   return min_delay + (MathRand() % (max_delay - min_delay + 1));
}

//+------------------------------------------------------------------+
//| Start a staggered 3-order recovery cluster                       |
//+------------------------------------------------------------------+
bool StartRecoveryCluster(int level, ENUM_POSITION_TYPE type)
{
   if(m_cluster_pending)
      return false;

   m_cluster_pending = true;
   m_cluster_level = level;
   m_cluster_type = type;
   m_cluster_next_order = 0;
   m_cluster_success_count = 0;
   m_next_order_time = TimeCurrent();

   PrintFormat(">> Level %d cluster scheduled: 3 orders with %d-%d sec gaps.",
               level,
               MathMax(1, InpMinOrderDelaySeconds),
               MathMax(MathMax(1, InpMinOrderDelaySeconds), InpMaxOrderDelaySeconds));
   return true;
}

//+------------------------------------------------------------------+
//| Process one pending cluster order without blocking OnTick        |
//+------------------------------------------------------------------+
void ProcessPendingRecoveryCluster()
{
   if(!m_cluster_pending)
      return;

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return;

   ENUM_POSITION_TYPE basket_type;
   double vwap, total_vol, initial_price;
   int count;

   if(!GetBasketStats(basket_type, vwap, total_vol, count, initial_price))
   {
      Print(">> Pending recovery cluster cancelled because basket is no longer open.");
      ResetClusterState();
      return;
   }

   if(TimeCurrent() < m_next_order_time)
      return;

   double lot1 = InpInitialLot;
   double lot2 = NormalizeDouble(m_cluster_level * InpInitialLot, 2);
   double lot3 = NormalizeDouble(m_cluster_level * InpInitialLot, 2);
   double lots[3] = { lot1, lot2, lot3 };

   int order_index = m_cluster_next_order;
   string comment = StringFormat("%s L%d-%d",
                                 InpTradeComment,
                                 m_cluster_level,
                                 order_index + 1);

   bool placed = false;
   double requested_price = 0.0;

   if(m_cluster_type == POSITION_TYPE_BUY)
   {
      requested_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      placed = m_trade.Buy(lots[order_index], _Symbol, requested_price,
                           0.0, 0.0, comment);
   }
   else
   {
      requested_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      placed = m_trade.Sell(lots[order_index], _Symbol, requested_price,
                            0.0, 0.0, comment);
   }

   if(placed)
   {
      m_cluster_success_count++;
      PrintFormat(">> Level %d Cluster Order %d/3 Placed: %s %.2f lots @ %.2f",
                  m_cluster_level,
                  order_index + 1,
                  (m_cluster_type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                  lots[order_index],
                  requested_price);
      
      // When first order of the cluster is placed, play the Level audio (level 1 to 10)
      if(order_index == 0)
      {
         PlayLevelAudio(m_cluster_level);
      }
   }
   else
   {
      PrintFormat("!! Failed Level %d Cluster Order %d/3: retcode=%u (%s), last_error=%d",
                  m_cluster_level,
                  order_index + 1,
                  m_trade.ResultRetcode(),
                  m_trade.ResultRetcodeDescription(),
                  GetLastError());
      PlayCustomAudio("Timeout.wav");
   }

   m_cluster_next_order++;

   if(m_cluster_next_order >= 3)
   {
      int completed_level = m_cluster_level;
      int success_count = m_cluster_success_count;

      ResetClusterState();

      if(success_count > 0)
      {
         m_current_grid_level = completed_level;

         double new_vwap, new_tot_vol, new_init_price;
         int new_count;
         ENUM_POSITION_TYPE new_type;

         if(GetBasketStats(new_type, new_vwap, new_tot_vol,
                           new_count, new_init_price))
         {
            UpdateBasketTakeProfit(new_type, new_vwap);
         }

         PrintFormat(">> Level %d cluster sequence complete: %d/3 orders placed.",
                     completed_level,
                     success_count);
      }
      return;
   }

   int delay = GetOrderDelaySeconds();
   m_next_order_time = TimeCurrent() + delay;

   PrintFormat(">> Level %d: waiting %d sec before cluster order %d/3.",
               m_cluster_level,
               delay,
               m_cluster_next_order + 1);
}

//+------------------------------------------------------------------+
//| Open a 3-order recovery cluster for level (1 to 10)              |
//+------------------------------------------------------------------+
bool OpenRecoveryCluster(int level, ENUM_POSITION_TYPE type)
{
   return StartRecoveryCluster(level, type);
}

//+------------------------------------------------------------------+
//| Check entry conditions on M1 closed candles                      |
//| STRICT SINGLE-DIRECTION LOCK: Only called when 0 open positions  |
//+------------------------------------------------------------------+
void CheckInitialEntry()
{
   if(m_cluster_pending || !m_license_active)
      return;

   // Check spread filter
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      PrintFormat("Spread %d exceeds max allowed %d. Skipping entry.", spread, InpMaxSpreadPoints);
      return;
   }

   // Fetch recent closed candles: 1, 2, 3
   double close0 = iClose(_Symbol, InpTimeframe, 1); // latest closed bar
   double open0  = iOpen(_Symbol,  InpTimeframe, 1);
   double high0  = iHigh(_Symbol,  InpTimeframe, 1);
   double low0   = iLow(_Symbol,   InpTimeframe, 1);

   double close1 = iClose(_Symbol, InpTimeframe, 2);
   double high1  = iHigh(_Symbol,  InpTimeframe, 2);
   double low1   = iLow(_Symbol,   InpTimeframe, 2);

   double close2 = iClose(_Symbol, InpTimeframe, 3);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // --- BUY SIGNAL: Sharp downward dip / oversold extension ---
   bool buy_condition = (close0 < open0) && (close0 < low1) && (close0 < close2);
   double drop_points = MathAbs(close0 - close2);

   if(buy_condition && drop_points >= InpMinSpikePoints)
   {
      double sl = (InpStopLossPoints > 0) ? NormalizeDouble(ask - InpStopLossPoints, digits) : 0.0;
      double tp = NormalizeDouble(ask + InpTakeProfitPoints, digits);

      PrintFormat(">> BUY SIGNAL TRIGGERED @ Ask: %.2f (Dip: %.2f pts). Opening initial lot %.2f...", 
                  ask, drop_points, InpInitialLot);
      if(m_trade.Buy(InpInitialLot, _Symbol, ask, sl, tp, InpTradeComment))
      {
         m_initial_price = ask;
         m_current_grid_level = 0;
         PlayCustomAudio("entry placed.wav");
      }
      return;
   }

   // --- SELL SIGNAL: Sharp upward spike / overbought extension ---
   bool sell_condition = (close0 > open0) && (close0 > high1) && (close0 > close2);
   double surge_points = MathAbs(close0 - close2);

   if(sell_condition && surge_points >= InpMinSpikePoints)
   {
      double sl = (InpStopLossPoints > 0) ? NormalizeDouble(bid + InpStopLossPoints, digits) : 0.0;
      double tp = NormalizeDouble(bid - InpTakeProfitPoints, digits);

      PrintFormat(">> SELL SIGNAL TRIGGERED @ Bid: %.2f (Surge: %.2f pts). Opening initial lot %.2f...", 
                  bid, surge_points, InpInitialLot);
      if(m_trade.Sell(InpInitialLot, _Symbol, bid, sl, tp, InpTradeComment))
      {
         m_initial_price = bid;
         m_current_grid_level = 0;
         PlayCustomAudio("entry placed.wav");
      }
      return;
   }
}

//+------------------------------------------------------------------+
//| Manage 3-order cluster recovery grid for open positions          |
//+------------------------------------------------------------------+
void ManageRecoveryGrid(ENUM_POSITION_TYPE basket_type, double vwap, double total_vol, int count, double initial_price)
{
   if(!InpEnableRecovery || m_cluster_pending || !m_license_active)
      return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Determine adverse distance from initial entry price
   double adverse_distance = 0.0;
   if(basket_type == POSITION_TYPE_BUY)
      adverse_distance = initial_price - ask; // falling price is adverse for BUY
   else if(basket_type == POSITION_TYPE_SELL)
      adverse_distance = bid - initial_price; // rising price is adverse for SELL

   // Check next level to fire (from m_current_grid_level + 1 up to InpMaxGridLevels)
   int next_level = m_current_grid_level + 1;
   if(next_level > InpMaxGridLevels)
      return; // Reached maximum grid levels (Level 10)

   double required_distance = next_level * InpGridStepPoints;

   if(adverse_distance >= required_distance)
   {
      PrintFormat(">> ADVERSE DISTANCE: %.2f pts >= Required %.2f pts for Level %d. Triggering 3-Order Cluster...", 
                  adverse_distance, required_distance, next_level);

      if(OpenRecoveryCluster(next_level, basket_type))
      {
         m_current_grid_level = next_level;

         // Recalculate basket VWAP and update all TP across the basket
         double new_vwap, new_tot_vol, new_init_price;
         int new_count;
         ENUM_POSITION_TYPE new_type;
         if(GetBasketStats(new_type, new_vwap, new_tot_vol, new_count, new_init_price))
         {
            UpdateBasketTakeProfit(new_type, new_vwap);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Periodically re-verify license validity every tick
   if(!ValidateLicenseKey(InpLicenseKey))
   {
      m_license_active = false;
      UpdateChartDashboard(0, 0, 0, POSITION_TYPE_BUY);
      return;
   }

   // Check if loss exceeds $1500 threshold and play Timeout audio
   CheckLossTimeoutAlert();

   // Process at most one pending recovery order when its delay has elapsed
   ProcessPendingRecoveryCluster();

   ENUM_POSITION_TYPE basket_type;
   double vwap = 0.0;
   double total_vol = 0.0;
   double initial_price = 0.0;
   int open_count = 0;

   bool has_positions = GetBasketStats(basket_type, vwap, total_vol,
                                       open_count, initial_price);

   // Update chart dashboard HUD every tick (showing version v1, spread status, trial days, basket stats)
   UpdateChartDashboard(open_count, total_vol, vwap, basket_type);

   if(!has_positions)
   {
      // --- ZERO POSITIONS: reset basket state ---
      bool just_closed_basket = m_had_positions_previous_tick;

      if(m_current_grid_level > 0 || m_initial_price > 0.0 || m_cluster_pending)
      {
         m_current_grid_level = 0;
         m_initial_price = 0.0;
         ResetClusterState();
      }

      // Check entry conditions on new candle or immediately after basket close
      if(just_closed_basket || IsNewBar())
         CheckInitialEntry();

      m_had_positions_previous_tick = false;
   }
   else
   {
      m_had_positions_previous_tick = true;

      // --- POSITIONS ACTIVE: strict single-direction lock ---
      if(m_initial_price == 0.0)
         m_initial_price = initial_price;

      // Do not derive the level while a staggered cluster is still being placed
      if(!m_cluster_pending && open_count > 1)
      {
         int derived_level = (open_count - 1) / 3;
         if(derived_level > m_current_grid_level)
            m_current_grid_level = derived_level;
      }

      // 1. Manage recovery grid
      ManageRecoveryGrid(basket_type, vwap, total_vol,
                         open_count, m_initial_price);

      // 2. Check basket exit
      CheckBasketExit(basket_type, vwap, open_count);
   }
}

//+------------------------------------------------------------------+
//| Trade transaction callback for real-time TP hit sound alerts     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                         const MqlTradeRequest& request,
                         const MqlTradeResult& result)
{
   if(!InpEnableSounds)
      return;

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         if(magic == InpMagicNumber && HistoryDealGetString(trans.deal, DEAL_SYMBOL) == _Symbol)
         {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
            {
               ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
               double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
               if(reason == DEAL_REASON_TP || profit > 0.0)
               {
                  datetime now = TimeCurrent();
                  if(now - m_last_tphit_audio_time >= 3)
                  {
                     m_last_tphit_audio_time = now;
                     PrintFormat(">> Deal #%I64u closed at TP (Profit: $%.2f). Playing TP hit sound!", trans.deal, profit);
                     PlayCustomAudio("tp hit.wav");
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
