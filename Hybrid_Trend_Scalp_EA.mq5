//+------------------------------------------------------------------+
//|                                      Hybrid_Trend_Scalp_EA.mq5  |
//|                        Trend + Scalp + Recovery Hybrid System    |
//|                                              Version: 3.0        |
//+------------------------------------------------------------------+
#property copyright "Hybrid EA System"
#property version   "3.00"
#property description "Trend Following + Scalping + Recovery System"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Arrays\ArrayObj.mqh>

//--- Global Objects
CTrade trade;
CPositionInfo positionInfo;
CSymbolInfo symbolInfo;

//+------------------------------------------------------------------+
//| ENUMs and STRUCTs                                                |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION { TREND_UP, TREND_DOWN, TREND_SIDEWAYS };
enum ENUM_SYSTEM_TYPE { SYSTEM_TREND, SYSTEM_SCALP, SYSTEM_RECOVERY, SYSTEM_HYBRID };
enum ENUM_TRADING_MODE { MODE_TREND_ONLY, MODE_SCALP_ONLY, MODE_HYBRID, MODE_TREND_FIRST };
enum ENUM_ENTRY_MODE { ENTRY_CROSSOVER, ENTRY_PULLBACK };

//--- Recovery Group Structure
struct SRecoveryGroup
{
   ulong           tickets[];
   ENUM_POSITION_TYPE type;
   double          totalVolume;
   double          averageEntry;
   double          targetProfit;
   bool            active;
   ulong           magic;
   datetime        createdTime;
   int             attemptCount;
   
   // ฟังก์ชัน init แทน constructor
   void Init()
   {
      ArrayResize(tickets, 0);
      totalVolume = 0;
      averageEntry = 0;
      targetProfit = 0;
      active = false;
      magic = 0;
      createdTime = TimeCurrent();
      attemptCount = 0;
   }
};
class CRecoveryGroup : public CObject  // ✅ ใช้ class
{
public:
   ulong           tickets[];
   ENUM_POSITION_TYPE type;
   double          totalVolume;
   double          averageEntry;
   double          targetProfit;
   bool            active;
   ulong           magic;
   datetime        createdTime;
   int             attemptCount;
   
   CRecoveryGroup() : 
      type(POSITION_TYPE_BUY),
      totalVolume(0),
      averageEntry(0),
      targetProfit(0),
      active(false),
      magic(0),
      createdTime(TimeCurrent()),
      attemptCount(0)
   {
      ArrayResize(tickets, 0);
   }
};
//--- ต้องเปลี่ยน CArrayObj เป็น array ปกติ
//SRecoveryGroup recoveryGroups[];
CArrayObj recoveryGroups;
//--- Profit Pool Structure
struct SProfitPool
{
   double trendProfit;
   double scalpProfit;
   double recoveryProfit;
   double totalProfit;
   
   SProfitPool()
   {
      trendProfit = 0;
      scalpProfit = 0;
      recoveryProfit = 0;
      totalProfit = 0;
   }
   
   void AddProfit(ENUM_SYSTEM_TYPE system, double profit)
   {
      switch(system)
      {
         case SYSTEM_TREND: trendProfit += profit; break;
         case SYSTEM_SCALP: scalpProfit += profit; break;
         case SYSTEM_RECOVERY: recoveryProfit += profit; break;
         case SYSTEM_HYBRID: scalpProfit += profit; break;
      }
      totalProfit = trendProfit + scalpProfit + recoveryProfit;
   }
   
   double GetProfitForSystem(ENUM_SYSTEM_TYPE system)
   {
      switch(system)
      {
         case SYSTEM_TREND: return trendProfit;
         case SYSTEM_SCALP: return scalpProfit + recoveryProfit; // Scalp สามารถใช้ recovery profit ได้
         case SYSTEM_RECOVERY: return recoveryProfit + scalpProfit; // Recovery สามารถใช้ scalp profit ได้
         default: return totalProfit;
      }
   }
   
   void ResetDaily()
   {
      trendProfit = 0;
      scalpProfit = 0;
      recoveryProfit = 0;
      totalProfit = 0;
   }
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "===== SYSTEM CONFIGURATION ====="
input ENUM_TRADING_MODE Trading_Mode = MODE_HYBRID;
input bool Allow_Trend_Trades = true;
input bool Allow_Scalp_Trades = true;
input bool Allow_Recovery_Trades = true;

//--- Trend System Settings
input group "===== TREND SYSTEM SETTINGS ====="
input ENUM_TIMEFRAMES TF_Trend_Large = PERIOD_H1;
input ENUM_TIMEFRAMES TF_Trend_Medium = PERIOD_M15;
input ENUM_TIMEFRAMES TF_Trend_Entry = PERIOD_M5;
input int Trend_EMA_Fast = 9;
input int Trend_EMA_Slow = 21;
input int Trend_ADX_Period = 14;
input double Trend_ADX_Min = 20.0;
input int Trend_RSI_Period = 14;
input double Trend_RSI_BuyMax = 70.0;
input double Trend_RSI_SellMin = 30.0;
input double Trend_SL_ATR_Mult = 1.5;
input double Trend_TP_ATR_Mult = 2.0;

//--- Scalp System Settings
input group "===== SCALP SYSTEM SETTINGS ====="
input ENUM_TIMEFRAMES TF_Scalp_Trend = PERIOD_M5;
input ENUM_TIMEFRAMES TF_Scalp_Momentum = PERIOD_M1;
input ENUM_TIMEFRAMES TF_Scalp_Entry = PERIOD_M1;
input int Scalp_EMA_Fast = 9;
input int Scalp_EMA_Slow = 21;
input ENUM_ENTRY_MODE Scalp_Entry_Mode = ENTRY_CROSSOVER;
input double Pullback_Distance_Pips = 10.0;
input int Scalp_ADX_Period = 14;
input double Scalp_ADX_Min = 15.0;
input int Scalp_RSI_Period = 14;
input double Scalp_RSI_Overbought = 75.0;
input double Scalp_RSI_Oversold = 25.0;
input double Scalp_SL_ATR_Mult = 1.0;
input double Scalp_TP_ATR_Mult = 1.5;

//--- Multi-TP Settings
input group "===== MULTI-TP SETTINGS ====="
input bool Use_Multi_TP = true;
input double TP1_ATR_Multiplier = 1.0;
input double TP2_ATR_Multiplier = 1.5;
input double TP3_ATR_Multiplier = 2.0;
input bool Partial_Close_Enabled = true;
input double Partial_Close_TP1 = 30.0;
input double Partial_Close_TP2 = 30.0;
input double Partial_Close_TP3 = 40.0;

//--- Recovery System Settings
input group "===== RECOVERY SYSTEM SETTINGS ====="
input bool Enable_Recovery_System = true;
input double Recovery_Target_Amount = 30.0;
input double Recovery_Lot_Multiplier = 1.5;
input int Max_Recovery_Attempts = 3;
input bool Use_Smart_Recovery_TP = true;
input int Recovery_Magic_Number = 88888;

//--- Grid Recovery Settings
input group "===== GRID RECOVERY SETTINGS ====="
input bool Enable_Grid_Recovery = false;
input int Max_Grid_Levels = 3;
input double Grid_Spacing_Pips = 20.0;
input double Grid_Lot_Multiplier = 1.5;

//--- Breakeven Settings
input group "===== BREAKEVEN SETTINGS ====="
input bool Enable_Breakeven_Stop = true;
input double BE_Trigger_Pips = 15.0;
input double BE_Lock_Pips = 2.0;

//--- Risk Management
input group "===== RISK MANAGEMENT ====="
input bool Use_Risk_Percent = true;
input double Risk_Percent = 1.0;
input double Fixed_Lot = 0.01;
input double Max_Daily_Loss_Percent = 5.0;
input double Max_Drawdown_Percent = 20.0;
input int Max_Trend_Positions = 2;
input int Max_Scalp_Positions = 3;
input int Max_Total_Positions = 5;

//--- Profit Targets
input group "===== PROFIT TARGETS ====="
input double Daily_Target_Percent = 3.0;
input double Weekly_Target_Percent = 10.0;
input double Monthly_Target_Percent = 20.0;
input double Scalp_Daily_Target = 50.0;    // ใน $
input double Recovery_Daily_Target = 30.0; // ใน $
input bool Auto_Close_At_Target = true;

//--- Filters
input group "===== MARKET FILTERS ====="
input bool Use_ADX_Filter = true;
input bool Use_RSI_Filter = true;
input bool Use_ATR_Filter = true;
input bool Use_Spread_Filter = true;
input int Max_Spread_Points = 6;
input bool Use_Time_Filter = true;
input int Trading_Start_Hour = 19;    // Bangkok Time
input int Trading_End_Hour = 23;      // Bangkok Time
input bool Skip_High_Impact_News = true;
input int Minutes_Before_News = 30;
input int Minutes_After_News = 60;

//--- Other Settings
input group "===== OTHER SETTINGS ====="
input ulong Magic_Number = 77777;
input int Slippage = 3;
input string Comment_Text = "Hybrid_EA";
input bool Enable_Alerts = true;
input bool Enable_Email_Alerts = false;
input bool Enable_Push_Alerts = false;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
// Indicator Handles
int hTrendEMA_Fast, hTrendEMA_Slow;
int hScalpEMA_Fast, hScalpEMA_Slow;
int hTrendADX, hTrendRSI, hTrendATR;
int hScalpADX, hScalpRSI, hScalpATR;

// System Variables
ENUM_TREND_DIRECTION currentTrend;
ENUM_TREND_DIRECTION previousTrend;
SProfitPool profitPool;
datetime lastResetTime;
double dailyBalanceStart;

// Position Counters
int trendPositionCount;
int scalpPositionCount;
int recoveryPositionCount;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // อย่าทำแบบนี้ใน OnInit: ❌
   // IndicatorRelease(hTrendEMA_Fast);  // WRONG PLACE!
   
   // Initialize symbol info
   if(!symbolInfo.Name(_Symbol))
   {
      Print("Failed to initialize symbol info");
      return INIT_FAILED;
   }
   symbolInfo.RefreshRates();
   
   // Initialize indicator handles
   InitializeIndicators();
   
   // Set trade settings
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialize variables
   currentTrend = TREND_SIDEWAYS;
   previousTrend = TREND_SIDEWAYS;
   dailyBalanceStart = AccountInfoDouble(ACCOUNT_BALANCE);
   lastResetTime = TimeCurrent();
   
   // Initialize recovery groups array
   recoveryGroups.Clear();  // ✅ ถูกต้อง
   
   Print("=== Hybrid Trend+Scalp+Recovery EA Initialized ===");
   Print("Trading Mode: ", EnumToString(Trading_Mode));
   Print("Symbol: ", _Symbol, " | Point: ", symbolInfo.Point());
   Print("Account Balance: ", dailyBalanceStart);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialize Indicators                                            |
//+------------------------------------------------------------------+
void InitializeIndicators()
{
   // Trend System Indicators
   hTrendEMA_Fast = iMA(_Symbol, TF_Trend_Large, Trend_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hTrendEMA_Slow = iMA(_Symbol, TF_Trend_Large, Trend_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hTrendADX = iADX(_Symbol, TF_Trend_Large, Trend_ADX_Period);
   hTrendRSI = iRSI(_Symbol, TF_Trend_Large, Trend_RSI_Period, PRICE_CLOSE);
   hTrendATR = iATR(_Symbol, TF_Trend_Large, 14);
   
   // Scalp System Indicators
   hScalpEMA_Fast = iMA(_Symbol, TF_Scalp_Trend, Scalp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hScalpEMA_Slow = iMA(_Symbol, TF_Scalp_Trend, Scalp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hScalpADX = iADX(_Symbol, TF_Scalp_Trend, Scalp_ADX_Period);
   hScalpRSI = iRSI(_Symbol, TF_Scalp_Trend, Scalp_RSI_Period, PRICE_CLOSE);
   hScalpATR = iATR(_Symbol, TF_Scalp_Trend, 14);
   
   // Check handles
   if(hTrendEMA_Fast == INVALID_HANDLE || hTrendEMA_Slow == INVALID_HANDLE ||
      hScalpEMA_Fast == INVALID_HANDLE || hScalpEMA_Slow == INVALID_HANDLE)
   {
      Print("Error creating EMA indicators");
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(hTrendEMA_Fast);
   IndicatorRelease(hTrendEMA_Slow);
   IndicatorRelease(hScalpEMA_Fast);
   IndicatorRelease(hScalpEMA_Slow);
   IndicatorRelease(hTrendADX);
   IndicatorRelease(hTrendRSI);
   IndicatorRelease(hTrendATR);
   IndicatorRelease(hScalpADX);
   IndicatorRelease(hScalpRSI);
   IndicatorRelease(hScalpATR);
   
   // Clear recovery groups
   recoveryGroups.Clear();
   
   Print("EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check basic trading conditions
   if(!IsTradingAllowed()) return;
   
   // Update market data
   symbolInfo.RefreshRates();
   
   // Check time filter
   if(Use_Time_Filter && !IsTradingTime()) return;
   
   // Check spread filter
   if(Use_Spread_Filter && !CheckSpread()) return;
   
   // Check news filter
   if(Skip_High_Impact_News && IsNewsTime()) return;
   
   // Update profit pool
   UpdateProfitPool();
   
   // Check profit targets
   CheckProfitTargets();
   
   // Check daily loss limit
   if(CheckDailyLossLimit()) return;
   
   // Check max drawdown
   if(CheckMaxDrawdown()) return;
   
   // Update trend direction
   UpdateTrendDirection();
   
   // Check for trend change
   CheckTrendChange();
   
   // Manage existing positions
   ManageExistingPositions();
   
   // เพิ่มบรรทัดนี้: ตรวจสอบ Breakeven สำหรับพอร์ต
   CheckPortfolioBreakeven();
   
   // Check recovery groups
   ManageRecoveryGroups();
   
   // Generate new signals based on trading mode
   GenerateTradingSignals();
   
   // Update position counters
   UpdatePositionCounters();
   
   // Display dashboard (every 10 seconds)
   static datetime lastDisplayTime = 0;
   if(TimeCurrent() - lastDisplayTime >= 10)
   {
      DisplayDashboard();
      lastDisplayTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Update Trend Direction                                           |
//+------------------------------------------------------------------+
void UpdateTrendDirection()
{
   previousTrend = currentTrend;
   
   // Get EMA values for trend detection
   double emaFast = GetEMAValue(hTrendEMA_Fast, 0);
   double emaSlow = GetEMAValue(hTrendEMA_Slow, 0);
   double adx = GetADXValue(hTrendADX, 0);
   
   if(emaFast > emaSlow && adx >= Trend_ADX_Min)
   {
      currentTrend = TREND_UP;
   }
   else if(emaFast < emaSlow && adx >= Trend_ADX_Min)
   {
      currentTrend = TREND_DOWN;
   }
   else
   {
      currentTrend = TREND_SIDEWAYS;
   }
}

//+------------------------------------------------------------------+
//| Check Trend Change                                               |
//+------------------------------------------------------------------+
void CheckTrendChange()
{
   if(currentTrend != previousTrend && currentTrend != TREND_SIDEWAYS)
   {
      Print("Trend changed from ", EnumToString(previousTrend), 
            " to ", EnumToString(currentTrend));
      
      // Activate recovery system if enabled
      if(Enable_Recovery_System && Allow_Recovery_Trades)
      {
         ActivateRecoveryMode();
      }
      
      // Send alert
      if(Enable_Alerts)
      {
         Alert("Trend Changed: ", EnumToString(previousTrend), 
               " -> ", EnumToString(currentTrend));
      }
   }
}

//+------------------------------------------------------------------+
//| Activate Recovery Mode                                           |
//+------------------------------------------------------------------+
void ActivateRecoveryMode()
{
   Print("Activating Recovery Mode...");
   
   // Find positions that are against the new trend
   CArrayObj againstTrendPositions;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Check if position is against new trend (and not already in recovery)
         bool isAgainstTrend = false;
         
         if(currentTrend == TREND_UP && posType == POSITION_TYPE_SELL)
            isAgainstTrend = true;
         else if(currentTrend == TREND_DOWN && posType == POSITION_TYPE_BUY)
            isAgainstTrend = true;
         
         if(isAgainstTrend && magic == Magic_Number)
         {
            // Create recovery group for these positions
            CreateRecoveryGroup(ticket, posType);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create Recovery Group                                            |
//+------------------------------------------------------------------+
void CreateRecoveryGroup(ulong firstTicket, ENUM_POSITION_TYPE posType)
{
   CRecoveryGroup *group = new CRecoveryGroup();
   
   // Add the first ticket
   ArrayResize(group.tickets, 1);
   group.tickets[0] = firstTicket;
   group.type = posType;
   group.active = true;
   group.magic = Recovery_Magic_Number;
   
   // Calculate initial values
   PositionSelectByTicket(firstTicket);
   group.totalVolume = PositionGetDouble(POSITION_VOLUME);
   group.averageEntry = PositionGetDouble(POSITION_PRICE_OPEN);
   
   // Set target profit
   group.targetProfit = Recovery_Target_Amount;
   
   // Add to recovery groups array
   recoveryGroups.Add(group);
   
   Print("Recovery Group Created for ticket ", firstTicket);
   Print("Target Profit: $", group.targetProfit);
   
   // Open recovery position
   OpenRecoveryPosition(group);
}

//+------------------------------------------------------------------+
//| Open Recovery Position                                           |
//+------------------------------------------------------------------+
void OpenRecoveryPosition(CRecoveryGroup &group)
{
   if(!group.active) return;
   
   double recoveryLot = group.totalVolume * Recovery_Lot_Multiplier;
   recoveryLot = NormalizeVolume(recoveryLot);
   
   double currentPrice = 0;
   double slPrice = 0, tpPrice = 0;
   
   if(group.type == POSITION_TYPE_BUY)
   {
      // Original was BUY (trend was up), now trend is down
      // Open SELL to recover
      currentPrice = symbolInfo.Bid();
      
      // Calculate recovery TP
      if(Use_Smart_Recovery_TP)
      {
         tpPrice = CalculateRecoveryTP(group);
         slPrice = currentPrice + (group.averageEntry - currentPrice) * 1.5;
      }
      else
      {
         double atr = GetATRValue(hScalpATR, 0);
         slPrice = currentPrice + (atr * Scalp_SL_ATR_Mult);
         tpPrice = currentPrice - (atr * Scalp_TP_ATR_Mult);
      }
      
      // Open SELL position
      bool success = trade.Sell(recoveryLot, _Symbol, currentPrice, slPrice, tpPrice, 
                                "Recovery_SELL");
      
      if(success)
      {
         ulong newTicket = trade.ResultOrder();
         ArrayResize(group.tickets, ArraySize(group.tickets) + 1);
         group.tickets[ArraySize(group.tickets) - 1] = newTicket;
         
         // Recalculate average
         RecalculateRecoveryGroup(group);
         
         Print("Recovery SELL opened: Lot=", recoveryLot, 
               " | Avg Entry: ", group.averageEntry);
      }
   }
   else if(group.type == POSITION_TYPE_SELL)
   {
      // Original was SELL (trend was down), now trend is up
      // Open BUY to recover
      currentPrice = symbolInfo.Ask();
      
      // Calculate recovery TP
      if(Use_Smart_Recovery_TP)
      {
         tpPrice = CalculateRecoveryTP(group);
         slPrice = currentPrice - (currentPrice - group.averageEntry) * 1.5;
      }
      else
      {
         double atr = GetATRValue(hScalpATR, 0);
         slPrice = currentPrice - (atr * Scalp_SL_ATR_Mult);
         tpPrice = currentPrice + (atr * Scalp_TP_ATR_Mult);
      }
      
      // Open BUY position
      bool success = trade.Buy(recoveryLot, _Symbol, currentPrice, slPrice, tpPrice,
                               "Recovery_BUY");
      
      if(success)
      {
         ulong newTicket = trade.ResultOrder();
         ArrayResize(group.tickets, ArraySize(group.tickets) + 1);
         group.tickets[ArraySize(group.tickets) - 1] = newTicket;
         
         // Recalculate average
         RecalculateRecoveryGroup(group);
         
         Print("Recovery BUY opened: Lot=", recoveryLot,
               " | Avg Entry: ", group.averageEntry);
      }
   }
   
   group.attemptCount++;
}

//+------------------------------------------------------------------+
//| Calculate Recovery TP                                            |
//+------------------------------------------------------------------+
double CalculateRecoveryTP(CRecoveryGroup &group)
{
   if(group.type == POSITION_TYPE_BUY)
   {
      // For BUY recovery group (original BUY, recovery SELL)
      // We want price to go DOWN to make SELL profitable
      double requiredMove = group.targetProfit / (group.totalVolume * 10);
      return group.averageEntry - requiredMove;
   }
   else
   {
      // For SELL recovery group (original SELL, recovery BUY)
      // We want price to go UP to make BUY profitable
      double requiredMove = group.targetProfit / (group.totalVolume * 10);
      return group.averageEntry + requiredMove;
   }
}

//+------------------------------------------------------------------+
//| Recalculate Recovery Group                                       |
//+------------------------------------------------------------------+
void RecalculateRecoveryGroup(CRecoveryGroup &group)
{
   double totalCost = 0;
   group.totalVolume = 0;
   
   for(int i = 0; i < ArraySize(group.tickets); i++)
   {
      if(PositionSelectByTicket(group.tickets[i]))
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         
         group.totalVolume += volume;
         totalCost += volume * price;
      }
   }
   
   if(group.totalVolume > 0)
   {
      group.averageEntry = totalCost / group.totalVolume;
   }
}

//+------------------------------------------------------------------+
//| Manage Recovery Groups                                           |
//+------------------------------------------------------------------+
void ManageRecoveryGroups()
{
   for(int i = recoveryGroups.Total() - 1; i >= 0; i--)
   {
      CRecoveryGroup *group = recoveryGroups.At(i);
      if(!group) continue;
      
      if(!group.active) continue;
      
      // Check if target reached
      double currentProfit = CalculateGroupProfit(group);
      
      if(currentProfit >= group.targetProfit)
      {
         // Target reached - close all positions in group
         CloseRecoveryGroup(group);
         recoveryGroups.Delete(i);
         Print("Recovery Group Target Reached! Profit: $", currentProfit);
      }
      else if(group.attemptCount >= Max_Recovery_Attempts)
      {
         // Max attempts reached - close with whatever profit/loss
         CloseRecoveryGroup(group);
         recoveryGroups.Delete(i);
         Print("Max Recovery Attempts Reached. Closing group.");
      }
      else if(TimeCurrent() - group.createdTime > 86400) // 24 hours
      {
         // Timeout - close group
         CloseRecoveryGroup(group);
         recoveryGroups.Delete(i);
         Print("Recovery Timeout (24h). Closing group.");
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Group Profit                                           |
//+------------------------------------------------------------------+
double CalculateGroupProfit(CRecoveryGroup &group)
{
   double totalProfit = 0;
   
   for(int i = 0; i < ArraySize(group.tickets); i++)
   {
      if(PositionSelectByTicket(group.tickets[i]))
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Close Recovery Group                                             |
//+------------------------------------------------------------------+
void CloseRecoveryGroup(CRecoveryGroup &group)
{
   double totalProfit = 0;
   
   for(int i = 0; i < ArraySize(group.tickets); i++)
   {
      if(PositionSelectByTicket(group.tickets[i]))
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         totalProfit += profit;
         
         trade.PositionClose(group.tickets[i]);
      }
   }
   
   // Record profit
   profitPool.AddProfit(SYSTEM_RECOVERY, totalProfit);
   
   group.active = false;
   Print("Recovery Group Closed. Total Profit: $", totalProfit);
}

//+------------------------------------------------------------------+
//| Generate Trading Signals                                         |
//+------------------------------------------------------------------+
void GenerateTradingSignals()
{
   // Check trading mode
   if(Trading_Mode == MODE_TREND_ONLY || Trading_Mode == MODE_HYBRID || Trading_Mode == MODE_TREND_FIRST)
   {
      if(Allow_Trend_Trades)
         CheckTrendSignals();
   }
   
   if(Trading_Mode == MODE_SCALP_ONLY || Trading_Mode == MODE_HYBRID)
   {
      if(Allow_Scalp_Trades)
         CheckScalpSignals();
   }
}

//+------------------------------------------------------------------+
//| Check Trend Signals                                              |
//+------------------------------------------------------------------+
void CheckTrendSignals()
{
   // Check if we can open more trend positions
   if(trendPositionCount >= Max_Trend_Positions) return;
   if(PositionsTotal() >= Max_Total_Positions) return;
   
   // Get trend indicators
   double emaFast_H1 = GetEMAValue(hTrendEMA_Fast, 0);
   double emaSlow_H1 = GetEMAValue(hTrendEMA_Slow, 0);
   double emaFast_M15 = GetEMAValue(hTrendEMA_Fast, TF_Trend_Medium);
   double emaSlow_M15 = GetEMAValue(hTrendEMA_Slow, TF_Trend_Medium);
   double emaFast_M5 = GetEMAValue(hTrendEMA_Fast, TF_Trend_Entry);
   double emaSlow_M5 = GetEMAValue(hTrendEMA_Slow, TF_Trend_Entry);
   
   // Get filters
   double adx = GetADXValue(hTrendADX, 0);
   double rsi = GetRSIValue(hTrendRSI, 0);
   double atr = GetATRValue(hTrendATR, 0);
   
   // Check BUY conditions
   if(emaFast_H1 > emaSlow_H1 &&                    // H1 trend up
      emaFast_M15 > emaSlow_M15 &&                  // M15 momentum up
      emaFast_M5 > emaSlow_M5 &&                    // M5 entry signal
      adx >= Trend_ADX_Min &&                       // ADX filter
      rsi < Trend_RSI_BuyMax &&                     // RSI not overbought
      atr > 0)                                      // Market not flat
   {
      // Check for EMA crossover on M5 for entry
      double emaFast_M5_prev = GetEMAValue(hTrendEMA_Fast, TF_Trend_Entry, 1);
      double emaSlow_M5_prev = GetEMAValue(hTrendEMA_Slow, TF_Trend_Entry, 1);
      
      if(emaFast_M5_prev <= emaSlow_M5_prev && emaFast_M5 > emaSlow_M5)
      {
         // BUY signal confirmed
         OpenTrendPosition(POSITION_TYPE_BUY);
      }
   }
   
   // Check SELL conditions
   else if(emaFast_H1 < emaSlow_H1 &&               // H1 trend down
           emaFast_M15 < emaSlow_M15 &&             // M15 momentum down
           emaFast_M5 < emaSlow_M5 &&               // M5 entry signal
           adx >= Trend_ADX_Min &&                  // ADX filter
           rsi > Trend_RSI_SellMin &&               // RSI not oversold
           atr > 0)                                 // Market not flat
   {
      // Check for EMA crossover on M5 for entry
      double emaFast_M5_prev = GetEMAValue(hTrendEMA_Fast, TF_Trend_Entry, 1);
      double emaSlow_M5_prev = GetEMAValue(hTrendEMA_Slow, TF_Trend_Entry, 1);
      
      if(emaFast_M5_prev >= emaSlow_M5_prev && emaFast_M5 < emaSlow_M5)
      {
         // SELL signal confirmed
         OpenTrendPosition(POSITION_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Open Trend Position                                              |
//+------------------------------------------------------------------+
void OpenTrendPosition(ENUM_POSITION_TYPE type)
{
   double lotSize = CalculateLotSize(SYSTEM_TREND);
   double currentPrice = (type == POSITION_TYPE_BUY) ? symbolInfo.Ask() : symbolInfo.Bid();
   double atr = GetATRValue(hTrendATR, 0);
   
   double slPrice = 0, tpPrice = 0;
   
   if(type == POSITION_TYPE_BUY)
   {
      slPrice = currentPrice - (atr * Trend_SL_ATR_Mult);
      tpPrice = currentPrice + (atr * Trend_TP_ATR_Mult);
      
      bool success = trade.Buy(lotSize, _Symbol, currentPrice, slPrice, tpPrice,
                               "Trend_BUY");
      
      if(success)
      {
         Print("Trend BUY opened: Lot=", lotSize, " | SL=", slPrice, " | TP=", tpPrice);
      }
   }
   else
   {
      slPrice = currentPrice + (atr * Trend_SL_ATR_Mult);
      tpPrice = currentPrice - (atr * Trend_TP_ATR_Mult);
      
      bool success = trade.Sell(lotSize, _Symbol, currentPrice, slPrice, tpPrice,
                                "Trend_SELL");
      
      if(success)
      {
         Print("Trend SELL opened: Lot=", lotSize, " | SL=", slPrice, " | TP=", tpPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Scalp Signals                                              |
//+------------------------------------------------------------------+
void CheckScalpSignals()
{

      Print("=== CHECK SCALP SIGNALS ===");
   
   // 1. ตรวจสอบ Trading Mode
   if(Trading_Mode == MODE_TREND_ONLY) {
      Print("❌ Trading Mode is TREND_ONLY - scalp disabled");
      return;
   }
   
   // 2. ตรวจสอบ Allow_Scalp_Trades
   if(!Allow_Scalp_Trades) {
      Print("❌ Allow_Scalp_Trades = false");
      return;
   }
   
   Print("✅ Trading Mode: ", EnumToString(Trading_Mode));
   Print("✅ Allow Scalp: ", Allow_Scalp_Trades);
   Print("✅ Current Trend: ", EnumToString(currentTrend));
   
   // 3. ตรวจสอบ Position Limits
   Print("Scalp Positions: ", scalpPositionCount, "/", Max_Scalp_Positions);
   Print("Total Positions: ", PositionsTotal(), "/", Max_Total_Positions);
   
   if(scalpPositionCount >= Max_Scalp_Positions) {
      Print("❌ Max scalp positions reached");
      return;
   }
   
   if(PositionsTotal() >= Max_Total_Positions) {
      Print("❌ Max total positions reached");
      return;
   }
   
   // 4. ตรวจสอบ Trend Direction
   if(currentTrend == TREND_DOWN) {
      Print("❌ Trend is DOWN - scalp only looks for SELL signals here");
      // Note: สำหรับ BUY scalps ต้องรอ TREND_UP
   }
   
   // 5. ถ้า Trend UP - พยายามหา BUY signal
   if(currentTrend == TREND_UP) {
      Print("✅ Trend is UP - looking for BUY scalp signals");
      
      // DEBUG: เปิด BUY ทันทีเพื่อทดสอบ
      DebugOpenScalpBuy();
   }
   
   Print("=== END CHECK SCALP ===");
   

   // Check if we can open more scalp positions
   if(scalpPositionCount >= Max_Scalp_Positions) return;
   if(PositionsTotal() >= Max_Total_Positions) return;
   
   // Check direction control - scalp only with trend
   if(!CheckScalpDirection()) return;
   
   // Get scalp indicators
   double emaFast_M5 = GetEMAValue(hScalpEMA_Fast, 0);
   double emaSlow_M5 = GetEMAValue(hScalpEMA_Slow, 0);
   double emaFast_M1 = GetEMAValue(hScalpEMA_Fast, TF_Scalp_Entry);
   double emaSlow_M1 = GetEMAValue(hScalpEMA_Slow, TF_Scalp_Entry);
   
   // Get filters
   double adx = GetADXValue(hScalpADX, 0);
   double rsi = GetRSIValue(hScalpRSI, 0);
   double atr = GetATRValue(hScalpATR, 0);
   
   // Check BUY conditions (only if trend is UP)
   if(currentTrend == TREND_UP || currentTrend == TREND_SIDEWAYS)
   {
      bool buySignal = false;
      
      if(Scalp_Entry_Mode == ENTRY_CROSSOVER)
      {
         // Crossover entry
         double emaFast_M1_prev = GetEMAValue(hScalpEMA_Fast, TF_Scalp_Entry, 1);
         double emaSlow_M1_prev = GetEMAValue(hScalpEMA_Slow, TF_Scalp_Entry, 1);
         
         buySignal = (emaFast_M1_prev <= emaSlow_M1_prev && emaFast_M1 > emaSlow_M1);
      }
      else
      {
         // Pullback entry
         double currentPrice = symbolInfo.Bid();
         double pullbackLevel = emaSlow_M1;
         
         buySignal = (currentPrice <= pullbackLevel + (Pullback_Distance_Pips * symbolInfo.Point()) &&
                     currentPrice >= pullbackLevel - (Pullback_Distance_Pips * symbolInfo.Point()) &&
                     emaFast_M1 > emaSlow_M1);
      }
      
      if(buySignal && adx >= Scalp_ADX_Min && rsi < Scalp_RSI_Overbought && atr > 0)
      {
         OpenScalpPosition(POSITION_TYPE_BUY);
      }
   }
   
   // Check SELL conditions (only if trend is DOWN)
   if(currentTrend == TREND_DOWN || currentTrend == TREND_SIDEWAYS)
   {
      bool sellSignal = false;
      
      if(Scalp_Entry_Mode == ENTRY_CROSSOVER)
      {
         // Crossover entry
         double emaFast_M1_prev = GetEMAValue(hScalpEMA_Fast, TF_Scalp_Entry, 1);
         double emaSlow_M1_prev = GetEMAValue(hScalpEMA_Slow, TF_Scalp_Entry, 1);
         
         sellSignal = (emaFast_M1_prev >= emaSlow_M1_prev && emaFast_M1 < emaSlow_M1);
      }
      else
      {
         // Pullback entry
         double currentPrice = symbolInfo.Ask();
         double pullbackLevel = emaSlow_M1;
         
         sellSignal = (currentPrice >= pullbackLevel - (Pullback_Distance_Pips * symbolInfo.Point()) &&
                      currentPrice <= pullbackLevel + (Pullback_Distance_Pips * symbolInfo.Point()) &&
                      emaFast_M1 < emaSlow_M1);
      }
      
      if(sellSignal && adx >= Scalp_ADX_Min && rsi > Scalp_RSI_Oversold && atr > 0)
      {
         OpenScalpPosition(POSITION_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Debug                                             |
//+------------------------------------------------------------------+

void DebugOpenScalpBuy()
{
   Print("DEBUG: Attempting to open test BUY scalp");
   
   double lotSize = 0.01;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = GetATRValue(hScalpATR, 0);
   
   Print("Price: ", price, " | ATR: ", atr);
   
   if(atr <= 0) {
      Print("❌ ATR is zero - cannot calculate SL/TP");
      return;
   }
   
   double slPrice = price - (atr * Scalp_SL_ATR_Mult);
   double tpPrice = price + (atr * Scalp_TP_ATR_Mult);
   
   Print("SL: ", slPrice, " | TP: ", tpPrice);
   
   bool success = trade.Buy(lotSize, _Symbol, price, slPrice, tpPrice, "SCALP_DEBUG_BUY");
   
   if(success) {
      Print("✅ DEBUG BUY SCALP OPENED SUCCESSFULLY");
      Print("Ticket: ", trade.ResultOrder());
   } else {
      Print("❌ Failed to open scalp: Error ", GetLastError());
   }
}
//+------------------------------------------------------------------+
//| Check Scalp Direction                                            |
//+------------------------------------------------------------------+
bool CheckScalpDirection()
{
   // Scalp must follow trend direction
   if(currentTrend == TREND_UP)
   {
      // Only allow BUY scalps
      return true; // Will check in signal generation
   }
   else if(currentTrend == TREND_DOWN)
   {
      // Only allow SELL scalps
      return true; // Will check in signal generation
   }
   
   // In sideways, check configuration
   return true;
}

//+------------------------------------------------------------------+
//| Open Scalp Position                                              |
//+------------------------------------------------------------------+
void OpenScalpPosition(ENUM_POSITION_TYPE type)
{
   double lotSize = CalculateLotSize(SYSTEM_SCALP);
   double currentPrice = (type == POSITION_TYPE_BUY) ? symbolInfo.Ask() : symbolInfo.Bid();
   double atr = GetATRValue(hScalpATR, 0);
   
   double slPrice = 0, tpPrice = 0;
   
   if(Use_Multi_TP)
   {
      // Use multi-TP system
      double tpLevels[3];
      CalcUniversalTP(currentPrice, (type == POSITION_TYPE_BUY) ? 1 : -1,
                      atr, TP1_ATR_Multiplier, TP2_ATR_Multiplier, TP3_ATR_Multiplier, tpLevels);
      
      if(type == POSITION_TYPE_BUY)
      {
         slPrice = currentPrice - (atr * Scalp_SL_ATR_Mult);
         // For multi-TP, we'll use the first TP level initially
         tpPrice = tpLevels[0];
         
         bool success = trade.Buy(lotSize, _Symbol, currentPrice, slPrice, tpPrice,
                                  "Scalp_BUY_TP1");
         
         if(success)
         {
            Print("Scalp BUY opened with Multi-TP: Lot=", lotSize);
         }
      }
      else
      {
         slPrice = currentPrice + (atr * Scalp_SL_ATR_Mult);
         // For multi-TP, we'll use the first TP level initially
         tpPrice = tpLevels[0];
         
         bool success = trade.Sell(lotSize, _Symbol, currentPrice, slPrice, tpPrice,
                                   "Scalp_SELL_TP1");
         
         if(success)
         {
            Print("Scalp SELL opened with Multi-TP: Lot=", lotSize);
         }
      }
   }
   else
   {
      // Use single TP
      if(type == POSITION_TYPE_BUY)
      {
         slPrice = currentPrice - (atr * Scalp_SL_ATR_Mult);
         tpPrice = currentPrice + (atr * Scalp_TP_ATR_Mult);
         
         bool success = trade.Buy(lotSize, _Symbol, currentPrice, slPrice, tpPrice,
                                  "Scalp_BUY");
         
         if(success)
         {
            Print("Scalp BUY opened: Lot=", lotSize, " | SL=", slPrice, " | TP=", tpPrice);
         }
      }
      else
      {
         slPrice = currentPrice + (atr * Scalp_SL_ATR_Mult);
         tpPrice = currentPrice - (atr * Scalp_TP_ATR_Mult);
         
         bool success = trade.Sell(lotSize, _Symbol, currentPrice, slPrice, tpPrice,
                                   "Scalp_SELL");
         
         if(success)
         {
            Print("Scalp SELL opened: Lot=", lotSize, " | SL=", slPrice, " | TP=", tpPrice);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Universal TP Levels                                    |
//+------------------------------------------------------------------+
void CalcUniversalTP(double entry, int dir, double atr,
                     double tp1_mult, double tp2_mult, double tp3_mult,
                     double &levels[])
{
   ArrayResize(levels, 3);
   
   if(atr <= 0.0)
   {
      levels[0] = levels[1] = levels[2] = 0.0;
      return;
   }
   
   double tp1_dist = atr * tp1_mult;
   double tp2_dist = atr * tp2_mult;
   double tp3_dist = atr * tp3_mult;
   
   if(dir > 0)   // BUY
   {
      levels[0] = NormalizeDouble(entry + tp1_dist, _Digits);
      levels[1] = NormalizeDouble(entry + tp2_dist, _Digits);
      levels[2] = NormalizeDouble(entry + tp3_dist, _Digits);
   }
   else          // SELL
   {
      levels[0] = NormalizeDouble(entry - tp1_dist, _Digits);
      levels[1] = NormalizeDouble(entry - tp2_dist, _Digits);
      levels[2] = NormalizeDouble(entry - tp3_dist, _Digits);
   }
}

//+------------------------------------------------------------------+
//| Manage Existing Positions                                        |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   // Check for TP/SL hits, trailing stops, breakeven, etc.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      string comment = PositionGetString(POSITION_COMMENT);
      
      // Determine system type from magic or comment
      ENUM_SYSTEM_TYPE systemType = GetSystemType(magic, comment);
      
      // Apply system-specific management
      switch(systemType)
      {
         case SYSTEM_TREND:
            ManageTrendPosition(ticket);
            break;
         case SYSTEM_SCALP:
            ManageScalpPosition(ticket);
            break;
         case SYSTEM_RECOVERY:
            // Recovery positions managed separately
            break;
         case SYSTEM_HYBRID:
            ManageScalpPosition(ticket); // Hybrid treated as scalp
            break;
      }
   }
}

//+------------------------------------------------------------------+
//| Get System Type                                                  |
//+------------------------------------------------------------------+
ENUM_SYSTEM_TYPE GetSystemType(ulong magic, string comment)
{
   if(magic == Magic_Number)
   {
      if(StringFind(comment, "Trend") >= 0) return SYSTEM_TREND;
      if(StringFind(comment, "Scalp") >= 0) return SYSTEM_SCALP;
      if(StringFind(comment, "Hybrid") >= 0) return SYSTEM_HYBRID;
   }
   else if(magic == Recovery_Magic_Number)
   {
      return SYSTEM_RECOVERY;
   }
   
   return SYSTEM_SCALP; // Default
}

//+------------------------------------------------------------------+
//| Manage Trend Position                                            |
//+------------------------------------------------------------------+
void ManageTrendPosition(ulong ticket)
{
   // Trend positions - let them run with TP/SL
   // No additional management needed
}

//+------------------------------------------------------------------+
//| Manage Scalp Position                                            |
//+------------------------------------------------------------------+
void ManageScalpPosition(ulong ticket)
{
   PositionSelectByTicket(ticket);
   
   // Check for multi-TP partial closes
   if(Use_Multi_TP && Partial_Close_Enabled)
   {
      CheckMultiTP(ticket);
   }
   
   // Check for breakeven stop
   if(Enable_Breakeven_Stop)
   {
      CheckBreakevenStop(ticket);
   }
}

//+------------------------------------------------------------------+
//| Check Multi-TP                                                   |
//+------------------------------------------------------------------+
void CheckMultiTP(ulong ticket)
{
   PositionSelectByTicket(ticket);
   
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   // Get ATR for TP calculation
   double atr = GetATRValue(hScalpATR, 0);
   
   // Calculate TP levels
   double tpLevels[3];
   CalcUniversalTP(entryPrice, (type == POSITION_TYPE_BUY) ? 1 : -1,
                   atr, TP1_ATR_Multiplier, TP2_ATR_Multiplier, TP3_ATR_Multiplier, tpLevels);
   
   // Check which TP levels have been hit
   for(int i = 0; i < 3; i++)
   {
      bool tpHit = false;
      
      if(type == POSITION_TYPE_BUY)
         tpHit = (currentPrice >= tpLevels[i]);
      else
         tpHit = (currentPrice <= tpLevels[i]);
      
      if(tpHit)
      {
         // Close partial volume
         double closeVolume = volume * (Partial_Close_TP1 / 100.0);
         if(i == 1) closeVolume = volume * (Partial_Close_TP2 / 100.0);
         if(i == 2) closeVolume = volume * (Partial_Close_TP3 / 100.0);
         
         closeVolume = NormalizeVolume(closeVolume);
         
         if(closeVolume > 0)
         {
            trade.PositionClosePartial(ticket, closeVolume);
            Print("Partial close at TP", i+1, ": ", closeVolume, " lots");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Breakeven Stop                                             |
//+------------------------------------------------------------------+
void CheckBreakevenStop(ulong ticket)
{
   // 1. ตรวจสอบและคำนวณข้อมูลพอร์ตทั้งหมดก่อน
   double portfolioProfit = 0;
   double totalLongVolume = 0, totalShortVolume = 0;
   double weightedLongPrice = 0, weightedShortPrice = 0;
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // คำนวณข้อมูลพอร์ตทั้งหมด (เฉพาะออเดอร์ของ EA นี้)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong posTicket = PositionGetTicket(i);
      if(!PositionSelectByTicket(posTicket)) continue;
      
      // ตรวจสอบว่าเป็นออเดอร์ของ EA เรา (ใช้ Magic Number)
      if(PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
      
      portfolioProfit += PositionGetDouble(POSITION_PROFIT);
      
      double volume = PositionGetDouble(POSITION_VOLUME);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(posType == POSITION_TYPE_BUY)
      {
         totalLongVolume += volume;
         weightedLongPrice += entryPrice * volume;
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         totalShortVolume += volume;
         weightedShortPrice += entryPrice * volume;
      }
   }
   
   // 2. คำนวณราคาเฉลี่ยถ่วงน้ำหนัก (Volume-Weighted Average Price)
   double avgLongPrice = (totalLongVolume > 0) ? weightedLongPrice / totalLongVolume : 0;
   double avgShortPrice = (totalShortVolume > 0) ? weightedShortPrice / totalShortVolume : 0;
   
   // 3. ตรวจสอบเงื่อนไข Breakeven สำหรับพอร์ตทั้งหมด
   if(portfolioProfit >= (BE_Trigger_Pips * 10 * symbolInfo.Point() * 100)) // แปลง pips เป็น $
   {
      // 4. คำนวณจุด Break-even จริงของพอร์ต
      double portfolioBreakEvenPrice = 0;
      double netVolume = totalLongVolume - totalShortVolume;
      
      if(netVolume > 0) // Net Long Position
      {
         // Break-even สำหรับ Long: Bid - (กำไร/volume)
         portfolioBreakEvenPrice = currentBid - (portfolioProfit / (netVolume * 10));
      }
      else if(netVolume < 0) // Net Short Position
      {
         // Break-even สำหรับ Short: Ask + (กำไร/volume)
         portfolioBreakEvenPrice = currentAsk + (portfolioProfit / (MathAbs(netVolume) * 10));
      }
      else // Hedged (Long = Short)
      {
         // กรณี对冲: ใช้ราคากลาง
         portfolioBreakEvenPrice = (currentBid + currentAsk) / 2;
      }
      
      // 5. ปรับ SL ของทุกออเดอร์ในพอร์ตไปยังจุด Break-even
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong posTicket = PositionGetTicket(i);
         if(!PositionSelectByTicket(posTicket)) continue;
         
         // ตรวจสอบว่าเป็นออเดอร์ของ EA เรา
         if(PositionGetInteger(POSITION_MAGIC) != Magic_Number) continue;
         
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         
         // คำนวณ SL ใหม่ตามประเภทออเดอร์
         double newSL = 0;
         if(posType == POSITION_TYPE_BUY)
         {
            newSL = portfolioBreakEvenPrice - (BE_Lock_Pips * symbolInfo.Point());
            if(newSL > currentSL) // อนุญาตให้ย้าย SL ขึ้นเท่านั้น
            {
               trade.PositionModify(posTicket, newSL, currentTP);
               Print("Portfolio Breakeven - BUY ticket ", posTicket, 
                     " SL moved to: ", newSL, " (Portfolio BE: ", portfolioBreakEvenPrice, ")");
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            newSL = portfolioBreakEvenPrice + (BE_Lock_Pips * symbolInfo.Point());
            if(newSL < currentSL) // อนุญาตให้ย้าย SL ลงเท่านั้น
            {
               trade.PositionModify(posTicket, newSL, currentTP);
               Print("Portfolio Breakeven - SELL ticket ", posTicket, 
                     " SL moved to: ", newSL, " (Portfolio BE: ", portfolioBreakEvenPrice, ")");
            }
         }
      }
      
      // 6. สรุปการทำงาน
      Print("=== PORTFOLIO BREAKEVEN ACTIVATED ===");
      Print("Portfolio Profit: $", portfolioProfit);
      Print("Long Volume: ", totalLongVolume, " | Avg Price: ", avgLongPrice);
      Print("Short Volume: ", totalShortVolume, " | Avg Price: ", avgShortPrice);
      Print("Net Volume: ", netVolume);
      Print("Portfolio Break-even Price: ", portfolioBreakEvenPrice);
      Print("All positions SL adjusted to breakeven + lock ", BE_Lock_Pips, " pips");
   }
}
//+------------------------------------------------------------------+
//| ฟังก์ชันเสริม: ตรวจสอบ Breakeven สำหรับพอร์ต (เรียกจาก OnTick)   |
//+------------------------------------------------------------------+
void CheckPortfolioBreakeven()
{
   static datetime lastCheck = 0;
   if(TimeCurrent() - lastCheck < 10) return; // ตรวจสอบทุก 10 วินาที
   
   if(Enable_Breakeven_Stop)
   {
      // ตรวจสอบพอร์ตทั้งหมด
      double portfolioProfit = 0;
      int positionCount = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && 
            PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         {
            portfolioProfit += PositionGetDouble(POSITION_PROFIT);
            positionCount++;
         }
      }
      
      // ถ้ามีออเดอร์มากกว่า 1 อัน ให้ใช้ระบบพอร์ต
      if(positionCount > 1)
      {
         // เรียกใช้ฟังก์ชัน CheckBreakevenStop ด้วย ticket ใดๆ
         // (ใช้ ticket แรกที่เจอเป็น parameter)
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket) && 
               PositionGetInteger(POSITION_MAGIC) == Magic_Number)
            {
               CheckBreakevenStop(ticket);
               break;
            }
         }
      }
   }
   
   lastCheck = TimeCurrent();
}
//+------------------------------------------------------------------+
//| Update Position Counters                                         |
//+------------------------------------------------------------------+
void UpdatePositionCounters()
{
   trendPositionCount = 0;
   scalpPositionCount = 0;
   recoveryPositionCount = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         string comment = PositionGetString(POSITION_COMMENT);
         
         if(magic == Magic_Number)
         {
            if(StringFind(comment, "Trend") >= 0)
               trendPositionCount++;
            else if(StringFind(comment, "Scalp") >= 0)
               scalpPositionCount++;
            else if(StringFind(comment, "Hybrid") >= 0)
               scalpPositionCount++;
         }
         else if(magic == Recovery_Magic_Number)
         {
            recoveryPositionCount++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update Profit Pool                                               |
//+------------------------------------------------------------------+
void UpdateProfitPool()
{
   static datetime lastUpdate = 0;
   datetime now = TimeCurrent();
   
   if(now - lastUpdate < 60) 
      return; // Update every minute
   
   double totalProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   // Reset daily if new day
   MqlDateTime currentTime, lastTime;
   TimeToStruct(now, currentTime);
   TimeToStruct(lastResetTime, lastTime);
   
   // ตรวจสอบว่าเป็นวันใหม่
   bool isNewDay = (currentTime.year != lastTime.year) ||
                   (currentTime.mon != lastTime.mon) ||
                   (currentTime.day != lastTime.day);
   
   if(isNewDay)
   {
      profitPool.ResetDaily();
      dailyBalanceStart = AccountInfoDouble(ACCOUNT_BALANCE);
      lastResetTime = now;
      Print("New day started. Balance: ", dailyBalanceStart);
   }
   
   lastUpdate = now;
}

//+------------------------------------------------------------------+
//| Check Profit Targets                                             |
//+------------------------------------------------------------------+
void CheckProfitTargets()
{
   // Check scalp daily target
   double scalpProfit = profitPool.GetProfitForSystem(SYSTEM_SCALP);
   if(scalpProfit >= Scalp_Daily_Target && Auto_Close_At_Target)
   {
      Print("Scalp daily target reached: $", scalpProfit);
      CloseAllPositionsBySystem(SYSTEM_SCALP);
      // Do NOT close trend positions!
   }
   
   // Check recovery daily target
   double recoveryProfit = profitPool.GetProfitForSystem(SYSTEM_RECOVERY);
   if(recoveryProfit >= Recovery_Daily_Target && Auto_Close_At_Target)
   {
      Print("Recovery daily target reached: $", recoveryProfit);
      // Recovery groups managed separately
   }
   
   // Check overall daily target
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyReturn = ((balance - dailyBalanceStart) / dailyBalanceStart) * 100;
   
   if(dailyReturn >= Daily_Target_Percent && Auto_Close_At_Target)
   {
      Print("Daily target reached: ", dailyReturn, "%");
      // Close all except trend positions
      CloseAllPositionsBySystem(SYSTEM_SCALP);
      CloseAllPositionsBySystem(SYSTEM_RECOVERY);
   }
}

//+------------------------------------------------------------------+
//| Close All Positions By System                                    |
//+------------------------------------------------------------------+
void CloseAllPositionsBySystem(ENUM_SYSTEM_TYPE system)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         string comment = PositionGetString(POSITION_COMMENT);
         
         ENUM_SYSTEM_TYPE posSystem = GetSystemType(magic, comment);
         
         if(posSystem == system)
         {
            trade.PositionClose(ticket);
            Print("Closed position from system: ", EnumToString(system));
         }
         else if(system == SYSTEM_SCALP && posSystem == SYSTEM_HYBRID)
         {
            // Also close hybrid positions when closing scalp
            trade.PositionClose(ticket);
            Print("Closed hybrid position with scalp");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Daily Loss Limit                                           |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyLoss = ((dailyBalanceStart - balance) / dailyBalanceStart) * 100;
   
   if(dailyLoss >= Max_Daily_Loss_Percent)
   {
      Print("Daily loss limit reached: ", dailyLoss, "%");
      if(Auto_Close_At_Target)
      {
         CloseAllPositionsBySystem(SYSTEM_SCALP);
         CloseAllPositionsBySystem(SYSTEM_RECOVERY);
         // Keep trend positions
      }
      return true; // Stop trading
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Max Drawdown                                               |
//+------------------------------------------------------------------+
bool CheckMaxDrawdown()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = ((balance - equity) / balance) * 100;
   
   if(drawdown >= Max_Drawdown_Percent)
   {
      Print("Max drawdown reached: ", drawdown, "%");
      if(Auto_Close_At_Target)
      {
         // Close all positions including trend
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
               trade.PositionClose(ticket);
            }
         }
      }
      return true; // Stop trading
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_SYSTEM_TYPE system)
{
   double lot = Fixed_Lot;
   
   if(Use_Risk_Percent)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (Risk_Percent / 100.0);
      
      // Different risk for different systems
      double systemRisk = Risk_Percent;
      if(system == SYSTEM_SCALP) systemRisk = Risk_Percent * 0.5;
      if(system == SYSTEM_TREND) systemRisk = Risk_Percent * 1.0;
      if(system == SYSTEM_RECOVERY) systemRisk = Risk_Percent * 0.75;
      
      riskAmount = balance * (systemRisk / 100.0);
      
      // Estimate SL distance
      double atr = GetATRValue(hScalpATR, 0);
      double slDistance = atr * (system == SYSTEM_TREND ? Trend_SL_ATR_Mult : Scalp_SL_ATR_Mult);
      
      if(slDistance > 0)
      {
         double tickValue = symbolInfo.TickValue();
         double tickSize = symbolInfo.TickSize();
         
         if(tickValue > 0 && tickSize > 0)
         {
            double riskPerLot = (slDistance / tickSize) * tickValue;
            if(riskPerLot > 0)
            {
               lot = riskAmount / riskPerLot;
            }
         }
      }
   }
   
   // Normalize lot size
   lot = NormalizeVolume(lot);
   
   return lot;
}

//+------------------------------------------------------------------+
//| Normalize Volume                                                 |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(volume < minLot) volume = minLot;
   if(volume > maxLot) volume = maxLot;
   
   int steps = (int)MathFloor(volume / lotStep);
   volume = steps * lotStep;
   
   return NormalizeDouble(volume, 2);
}

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
double GetEMAValue(int handle, int shift)
{
   double values[1];
   if(CopyBuffer(handle, 0, shift, 1, values) < 1) return 0;
   return values[0];
}

double GetEMAValue(int handle, ENUM_TIMEFRAMES tf, int shift)
{
   // For getting EMA from different timeframe
   double value = 0;
   // Implementation depends on your needs
   return value;
}

double GetADXValue(int handle, int shift)
{
   double values[1];
   if(CopyBuffer(handle, 0, shift, 1, values) < 1) return 0;
   return values[0];
}

double GetRSIValue(int handle, int shift)
{
   double values[1];
   if(CopyBuffer(handle, 0, shift, 1, values) < 1) return 50;
   return values[0];
}

double GetATRValue(int handle, int shift)
{
   double values[1];
   if(CopyBuffer(handle, 0, shift, 1, values) < 1) return 0;
   return values[0];
}

bool IsTradingAllowed()
{
   return MQLInfoInteger(MQL_TRADE_ALLOWED) && 
          TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
          (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL);
}

bool IsTradingTime()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   int currentHour = dt.hour;
   
   if(Trading_Start_Hour < Trading_End_Hour)
   {
      return (currentHour >= Trading_Start_Hour && currentHour < Trading_End_Hour);
   }
   else
   {
      return (currentHour >= Trading_Start_Hour || currentHour < Trading_End_Hour);
   }
}

bool CheckSpread()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= Max_Spread_Points);
}

bool IsNewsTime()
{
   // Simplified news check - in real implementation, connect to news API
   return false;
}

//+------------------------------------------------------------------+
//| Display Dashboard                                                |
//+------------------------------------------------------------------+
void DisplayDashboard()
{
   Print("=== HYBRID EA DASHBOARD ===");
   Print("Time: ", TimeToString(TimeCurrent()));
   Print("Trend: ", EnumToString(currentTrend));
   Print("Positions - Trend: ", trendPositionCount, 
         " | Scalp: ", scalpPositionCount, 
         " | Recovery: ", recoveryPositionCount);
   Print("Profit Pool - Trend: $", profitPool.trendProfit, 
         " | Scalp: $", profitPool.scalpProfit, 
         " | Recovery: $", profitPool.recoveryProfit);
   Print("Recovery Groups: ", recoveryGroups.Total());
   Print("=== END DASHBOARD ===");
}
//+------------------------------------------------------------------+
