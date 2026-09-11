//+------------------------------------------------------------------+
//|                                    Jigurujingania_Bot_PDVR.mq5   |
//|                          Jigurujingania bot by PDVR              |
//|                             Powered by Razel Tech                |
//|                                      https://jugurujingania.bot  |
//+------------------------------------------------------------------+
#property copyright   "PDVR - Powered by Razel Tech"
#property link        "https://jugurujingania.bot"
#property version     "3.10"
#property description "Jigurujingania Bot by PDVR - XAUUSD M1 Adaptive Recovery Engine [Powered by Razel Tech]"
#property strict

// Include standard trade libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input Parameters ---
input group "=== 0. BETA TESTING & TRIAL PROTECTION ==="
input bool     InpEnableTrialGuard      = true;                     // Enable Trial Guard
input int      InpTrialDays             = 7;                        // Trial Duration in Days (e.g. 3 or 7)
input datetime InpTrialFixedExpiryDate  = D'2026.09.25 23:59:59';   // Fixed Hard Expiry Date (Fallback)
input bool     InpDemoOnly              = true;                     // Enforce Demo Account Only (Beta Safety)

input group "=== 1. SOUND & AUDIO NOTIFICATIONS ==="
input bool     InpEnableSounds          = true;                     // Enable Sound Alerts
input string   InpSoundEntry            = "expert.wav";             // Initial Entry Sound
input string   InpSoundRecovery         = "alert2.wav";             // Cluster Recovery Sound
input string   InpSoundExit             = "ok.wav";                 // Basket TakeProfit Exit Sound
input string   InpSoundAlert            = "timeout.wav";            // Warning / Expiration Sound

input group "=== 2. INITIAL TRADE PARAMETERS ==="
input double   InpInitialLot            = 0.01;                     // Initial Lot Size
input double   InpTakeProfitPoints      = 4.20;                     // Initial TP in Points (42 pips in Gold)
input double   InpStopLossPoints        = 0.00;                     // Initial SL in Points (0 = Disabled, relies on recovery grid)
input ulong    InpMagicNumber           = 1223335;                  // Magic Number (Unique ID)
input string   InpTradeComment          = "JJ Bot PDVR";            // Order Comment

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

//--- Trial Protection Variables
datetime           m_first_run_time        = 0;
bool               m_trial_expired         = false;
const string       TRIAL_GV_KEY            = "JJ_PDVR_FIRST_RUN";

//+------------------------------------------------------------------+
//| Play sound notification helper                                   |
//+------------------------------------------------------------------+
void PlayAudioAlert(const string sound_file)
{
   if(InpEnableSounds && StringLen(sound_file) > 0)
   {
      PlaySound(sound_file);
   }
}

//+------------------------------------------------------------------+
//| Get remaining trial days (uses Broker Server Time)               |
//+------------------------------------------------------------------+
int GetRemainingTrialDays()
{
   datetime current_server_time = TimeTradeServer();
   if(current_server_time == 0)
      current_server_time = TimeCurrent();

   // 1. Check fixed expiry date
   if(InpTrialFixedExpiryDate > 0)
   {
      if(current_server_time >= InpTrialFixedExpiryDate)
         return 0;
      int days_left = (int)((InpTrialFixedExpiryDate - current_server_time) / 86400);
      return MathMax(0, days_left);
   }

   // 2. Check dynamic first-run expiry
   if(m_first_run_time > 0 && InpTrialDays > 0)
   {
      datetime expiry_time = m_first_run_time + (InpTrialDays * 86400);
      if(current_server_time >= expiry_time)
         return 0;
      int days_left = (int)((expiry_time - current_server_time) / 86400);
      return MathMax(0, days_left);
   }

   return InpTrialDays;
}

//+------------------------------------------------------------------+
//| Check trial validity (Broker Server Time verified)               |
//+------------------------------------------------------------------+
bool ValidateTrialSecurity()
{
   if(!InpEnableTrialGuard)
      return true;

   datetime current_server_time = TimeTradeServer();
   if(current_server_time == 0)
      current_server_time = TimeCurrent();

   // Enforce demo account check if enabled
   if(InpDemoOnly)
   {
      long account_type = AccountInfoInteger(ACCOUNT_TRADE_MODE);
      if(account_type != ACCOUNT_TRADE_MODE_DEMO)
      {
         string msg = "Jigurujingania Bot [Trial Error]: Beta version is restricted to DEMO accounts only for safety!";
         Print(msg);
         Alert(msg);
         PlayAudioAlert(InpSoundAlert);
         return false;
      }
   }

   // Check fixed expiry date
   if(InpTrialFixedExpiryDate > 0 && current_server_time >= InpTrialFixedExpiryDate)
   {
      string msg = "Jigurujingania Bot by PDVR: Testing trial period has expired! Contact PDVR / Razel Tech.";
      Print(msg);
      Alert(msg);
      PlayAudioAlert(InpSoundAlert);
      return false;
   }

   // Check first-run dynamic timestamp
   if(GlobalVariableCheck(TRIAL_GV_KEY))
   {
      m_first_run_time = (datetime)GlobalVariableGet(TRIAL_GV_KEY);
   }
   else
   {
      m_first_run_time = current_server_time;
      GlobalVariableSet(TRIAL_GV_KEY, (double)m_first_run_time);
   }

   if(InpTrialDays > 0)
   {
      datetime trial_expiry = m_first_run_time + (InpTrialDays * 86400);
      if(current_server_time >= trial_expiry)
      {
         string msg = StringFormat("Jigurujingania Bot by PDVR: %d-Day Trial has expired! Powered by Razel Tech.", InpTrialDays);
         Print(msg);
         Alert(msg);
         PlayAudioAlert(InpSoundAlert);
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Update On-Chart HUD Dashboard                                    |
//+------------------------------------------------------------------+
void UpdateChartDashboard(int open_count, double total_vol, double vwap, ENUM_POSITION_TYPE basket_type)
{
   int days_left = GetRemainingTrialDays();
   string status_str = m_trial_expired ? "EXPIRED (Trading Halted)" : StringFormat("ACTIVE (%d Days Trial Left)", days_left);
   string account_mode = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO) ? "DEMO (Beta Safe)" : "REAL";

   string basket_info = "No Active Basket (Scanning M1)";
   if(open_count > 0)
   {
      double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double target_price = (basket_type == POSITION_TYPE_BUY) ? (vwap + InpBasketTpPoints) : (vwap - InpBasketTpPoints);
      
      basket_info = StringFormat("%s Basket | Orders: %d | Lots: %.2f | Level: %d\n"
                                 "  VWAP: %.2f | Target: %.2f | Current: %.2f",
                                 (basket_type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                                 open_count, total_vol, m_current_grid_level,
                                 vwap, target_price, (basket_type == POSITION_TYPE_BUY ? current_bid : current_ask));
   }

   string hud = StringFormat(
      "=====================================================\n"
      "  JIGURUJINGANIA BOT by PDVR  v3.10\n"
      "  Powered by Razel Tech\n"
      "=====================================================\n"
      "  Status:         %s\n"
      "  Account:        #%I64d (%s)\n"
      "  Spread:         %I64d / Max %d pts\n"
      "  Audio Alerts:   %s\n"
      "-----------------------------------------------------\n"
      "  %s\n"
      "=====================================================",
      status_str,
      AccountInfoInteger(ACCOUNT_LOGIN), account_mode,
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), InpMaxSpreadPoints,
      (InpEnableSounds ? "ENABLED" : "MUTED"),
      basket_info
   );

   Comment(hud);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configure CTrade object
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetDeviationInPoints(20);
   MathSrand((uint)(GetTickCount() ^ (uint)TimeLocal()));

   // Perform trial security validation
   if(!ValidateTrialSecurity())
   {
      m_trial_expired = true;
      UpdateChartDashboard(0, 0, 0, POSITION_TYPE_BUY);
      return(INIT_FAILED);
   }

   m_trial_expired = false;

   PrintFormat("Jigurujingania Bot by PDVR [Powered by Razel Tech] initialized on %s %s. Magic: %I64u", 
               _Symbol, EnumToString(InpTimeframe), InpMagicNumber);
   PrintFormat("Trial Status: Valid for %d days. Demo Only: %s. Audio Alerts: %s.",
               GetRemainingTrialDays(), (InpDemoOnly ? "YES" : "NO"), (InpEnableSounds ? "YES" : "NO"));
   
   PlayAudioAlert(InpSoundEntry);
   UpdateChartDashboard(0, 0, 0, POSITION_TYPE_BUY);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment(""); // Clear on-chart HUD
   PrintFormat("Jigurujingania Bot by PDVR deinitialized. Reason: %d", reason);
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
   
   // Play exit sound
   PlayAudioAlert(InpSoundExit);

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
      
      // Play recovery alert sound
      PlayAudioAlert(InpSoundRecovery);
   }
   else
   {
      PrintFormat("!! Failed Level %d Cluster Order %d/3: retcode=%u (%s), last_error=%d",
                  m_cluster_level,
                  order_index + 1,
                  m_trade.ResultRetcode(),
                  m_trade.ResultRetcodeDescription(),
                  GetLastError());
      PlayAudioAlert(InpSoundAlert);
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
   if(m_cluster_pending || m_trial_expired)
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
         PlayAudioAlert(InpSoundEntry);
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
         PlayAudioAlert(InpSoundEntry);
      }
      return;
   }
}

//+------------------------------------------------------------------+
//| Manage 3-order cluster recovery grid for open positions          |
//+------------------------------------------------------------------+
void ManageRecoveryGrid(ENUM_POSITION_TYPE basket_type, double vwap, double total_vol, int count, double initial_price)
{
   if(!InpEnableRecovery || m_cluster_pending || m_trial_expired)
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
   // Periodically re-verify trial validity
   if(!ValidateTrialSecurity())
   {
      m_trial_expired = true;
      UpdateChartDashboard(0, 0, 0, POSITION_TYPE_BUY);
      return;
   }

   // Process at most one pending recovery order when its delay has elapsed.
   ProcessPendingRecoveryCluster();

   ENUM_POSITION_TYPE basket_type;
   double vwap = 0.0;
   double total_vol = 0.0;
   double initial_price = 0.0;
   int open_count = 0;

   bool has_positions = GetBasketStats(basket_type, vwap, total_vol,
                                       open_count, initial_price);

   // Update chart dashboard HUD every tick
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
