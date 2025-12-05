//+------------------------------------------------------------------+
//|                                               Scalp2Enhanced.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

#include "BaseStrategy.mqh"

//+------------------------------------------------------------------+
//| Smart Income Compensation Strategy                                |
//+------------------------------------------------------------------+
class CScalp2Enhanced : public CBaseStrategy
{
private:
   // Indicators
   int macdHandle;
   int stochHandle;
   int atrHandle;
   int volumeHandle;
   int pivotHandle;
   
   // Parameters
   int macdFast;
   int macdSlow;
   int macdSignal;
   int stochK;
   int stochD;
   int stochSlowing;
   int atrPeriod;
   int pivotPeriod;
   
   // Entry conditions
   double stochOverbought;
   double stochOversold;
   double divergenceThreshold;
   double volumeThreshold;
   
   // Risk management
   double riskPercent;
   double profitMultiplier;
   bool useDynamicRR;
   double minLotSize;
   double maxLotSize;
   
   // Income compensation
   double compensationTarget;    // รายได้ที่ต้องการชดเชย
   bool compensationMode;        // อยู่ในโหมดชดเชยหรือไม่
   double totalCompensated;      // ยอดชดเชยสะสม
   
   // Performance tracking (เฉพาะของ Scalp2)
   int compensationTrades;
   int successfulCompensations;
   double averageCompensation;
   
   // State variables
   double lastMACD;
   double lastSignal;
   double lastStochK;
   double lastStochD;
   double lastATR;
   double lastVolume;
   double lastHigh;
   double lastLow;
   double lastClose;
   
   // Pivot levels
   double pivotPoint;
   double resistance1;
   double support1;
   double resistance2;
   double support2;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CScalp2Enhanced() : 
      macdHandle(INVALID_HANDLE),
      stochHandle(INVALID_HANDLE),
      atrHandle(INVALID_HANDLE),
      volumeHandle(INVALID_HANDLE),
      pivotHandle(INVALID_HANDLE),
      macdFast(12),
      macdSlow(26),
      macdSignal(9),
      stochK(14),
      stochD(3),
      stochSlowing(3),
      atrPeriod(14),
      pivotPeriod(1),  // Daily pivots
      stochOverbought(80),
      stochOversold(20),
      divergenceThreshold(0.0001),
      volumeThreshold(1.5),
      riskPercent(0.8),      // น้อยกว่า Scalp1
      profitMultiplier(1.2),
      useDynamicRR(true),
      minLotSize(0.01),
      maxLotSize(0.05),
      compensationTarget(0.0),
      compensationMode(false),
      totalCompensated(0.0),
      compensationTrades(0),
      successfulCompensations(0),
      averageCompensation(0.0),
      lastMACD(0.0),
      lastSignal(0.0),
      lastStochK(50.0),
      lastStochD(50.0),
      lastATR(0.0),
      lastVolume(0.0),
      lastHigh(0.0),
      lastLow(0.0),
      lastClose(0.0),
      pivotPoint(0.0),
      resistance1(0.0),
      support1(0.0),
      resistance2(0.0),
      support2(0.0)
   {
      SetName("Scalp2Enhanced");
      SetType(EA_STRATEGY_SCALP2);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CScalp2Enhanced()
   {
      if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
      if(stochHandle != INVALID_HANDLE) IndicatorRelease(stochHandle);
      if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
      if(volumeHandle != INVALID_HANDLE) IndicatorRelease(volumeHandle);
   }
   
   //+------------------------------------------------------------------+
   //| Initialize strategy                                              |
   //+------------------------------------------------------------------+
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int magicNumber) override
   {
      if(!CBaseStrategy::Initialize(symbol, timeframe, magicNumber))
         return false;
      
      // Create indicators สำหรับ Scalp2
      macdHandle = iMACD(symbol, timeframe, macdFast, macdSlow, macdSignal, PRICE_CLOSE);
      stochHandle = iStochastic(symbol, timeframe, stochK, stochD, stochSlowing, MODE_SMA, STO_LOWHIGH);
      atrHandle = iATR(symbol, timeframe, atrPeriod);
      
      // Volume indicator
      volumeHandle = iVolumes(symbol, timeframe, VOLUME_TICK);
      
      if(macdHandle == INVALID_HANDLE || stochHandle == INVALID_HANDLE || 
         atrHandle == INVALID_HANDLE || volumeHandle == INVALID_HANDLE)
      {
         Print("Failed to create indicators for Scalp2Enhanced");
         return false;
      }
      
      Print("Scalp2Enhanced initialized: ", symbol, " ", EnumToString(timeframe));
      Print("Scalp2Enhanced: Smart Income Compensation System Ready");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update indicators                                                |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!IsInitialized()) return;
      
      string symbol = GetSymbol();
      ENUM_TIMEFRAMES tf = GetTimeframe();
      
      // Update MACD
      double macd[2], signal[2];
      CopyBuffer(macdHandle, MAIN_LINE, 0, 2, macd);
      CopyBuffer(macdHandle, SIGNAL_LINE, 0, 2, signal);
      lastMACD = macd[1];
      lastSignal = signal[1];
      
      // Update Stochastic
      double stochK[2], stochD[2];
      CopyBuffer(stochHandle, MAIN_LINE, 0, 2, stochK);
      CopyBuffer(stochHandle, SIGNAL_LINE, 0, 2, stochD);
      lastStochK = stochK[1];
      lastStochD = stochD[1];
      
      // Update ATR
      double atr[2];
      CopyBuffer(atrHandle, 0, 0, 2, atr);
      lastATR = atr[1];
      
      // Update Volume
      double volume[2];
      CopyBuffer(volumeHandle, 0, 0, 2, volume);
      lastVolume = volume[1];
      
      // Update Price data
      lastHigh = iHigh(symbol, tf, 1);
      lastLow = iLow(symbol, tf, 1);
      lastClose = iClose(symbol, tf, 1);
      
      // Calculate pivot points (simplified - ใช้ daily)
      CalculatePivotPoints();
      
      // Update compensation mode
      UpdateCompensationMode();
      
      // Debug info occasionally
      static int updateCount = 0;
      if(updateCount++ % 50 == 0)
      {
         Print("Scalp2Enhanced Updated: ATR=", lastATR, 
               ", StochK=", lastStochK, 
               ", CompensationMode=", compensationMode,
               ", Target=", compensationTarget);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Update compensation mode based on portfolio                      |
   //+------------------------------------------------------------------+
   void UpdateCompensationMode()
   {
      double portfolioProfit = GetPortfolioProfit();
      
      // ถ้า portfolio ขาดทุนมากกว่า $50 ให้เข้าสู่โหมดชดเชย
      if(portfolioProfit < -50.0)
      {
         compensationMode = true;
         compensationTarget = MathAbs(portfolioProfit) * 0.3; // ชดเชย 30% ของ loss
         
         if(compensationTarget > 100.0) compensationTarget = 100.0; // Limit
         if(compensationTarget < 10.0) compensationTarget = 10.0;   // Minimum
      }
      else
      {
         compensationMode = false;
         compensationTarget = 0.0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate daily pivot points                                     |
   //+------------------------------------------------------------------+
   void CalculatePivotPoints()
   {
      string symbol = GetSymbol();
      ENUM_TIMEFRAMES daily = PERIOD_D1;
      
      double high = iHigh(symbol, daily, 1);
      double low = iLow(symbol, daily, 1);
      double close = iClose(symbol, daily, 1);
      
      // Classic Pivot Points
      pivotPoint = (high + low + close) / 3;
      resistance1 = (2 * pivotPoint) - low;
      support1 = (2 * pivotPoint) - high;
      resistance2 = pivotPoint + (high - low);
      support2 = pivotPoint - (high - low);
   }
   
   //+------------------------------------------------------------------+
   //| Check for entry signal - SIMPLIFIED VERSION                     |
   //+------------------------------------------------------------------+
   int CheckSignal() override
   {
      if(!IsInitialized() || !IsActive()) 
         return 0;
      
      // เงื่อนไขง่ายๆ ไม่เข้มเกินไป: ให้ออกไม้ได้บ่อยขึ้น
      double currentPrice = SymbolInfoDouble(GetSymbol(), SYMBOL_BID);
      
      // 1. Stochastic overbought/oversold (เงื่อนไขหลัก)
      bool stochOverboughtSignal = (lastStochK > stochOverbought && lastStochD > stochOverbought);
      bool stochOversoldSignal = (lastStochK < stochOversold && lastStochD < stochOversold);
      
      // 2. Price at pivot levels (เงื่อนไขเสริม)
      bool nearResistance = MathAbs(currentPrice - resistance1) < (lastATR * 0.3);
      bool nearSupport = MathAbs(currentPrice - support1) < (lastATR * 0.3);
      
      // 3. Volume spike (optional)
      double avgVolume = GetAverageVolume(20);
      bool volumeSpike = lastVolume > (avgVolume * volumeThreshold);
      
      // SIMPLE ENTRY RULES - ไม่ซับซ้อนเกินไป
      
      // BUY Signal (ง่ายๆ):
      // - Stochastic oversold
      // - ใกล้ support
      if(stochOversoldSignal && nearSupport)
      {
         return 1; // Buy
      }
      
      // SELL Signal (ง่ายๆ):
      // - Stochastic overbought  
      // - ใกล้ resistance
      if(stochOverboughtSignal && nearResistance)
      {
         return -1; // Sell
      }
      
      // Additional: ถ้ามี volume spike ให้เพิ่มความมั่นใจ
      if(volumeSpike)
      {
         if(stochOversoldSignal) return 1;
         if(stochOverboughtSignal) return -1;
      }
      
      return 0;
   }
   
   //+------------------------------------------------------------------+
   //| Get average volume for comparison                                |
   //+------------------------------------------------------------------+
   double GetAverageVolume(int periods)
   {
      string symbol = GetSymbol();
      ENUM_TIMEFRAMES tf = GetTimeframe();
      
      double total = 0;
      for(int i = 1; i <= periods; i++)
      {
         total += iVolumes(symbol, tf, VOLUME_TICK, i);
      }
      
      return total / periods;
   }
   
   //+------------------------------------------------------------------+
   //| Check for entry with weight from TeamManager                     |
   //+------------------------------------------------------------------+
   bool CheckForEntry(double weight = 1.0) override
   {
      int signal = CheckSignal();
      if(signal == 0) return false;
      
      // Adjust weight for compensation mode
      double adjustedWeight = weight;
      if(compensationMode)
      {
         // ในโหมดชดเชย อาจเพิ่ม aggression เล็กน้อย
         adjustedWeight *= 1.2;
         Print("Scalp2Enhanced: Compensation Mode Active. Target: $", compensationTarget);
      }
      
      // Calculate lot size
      double lotSize = CalculateLotSize(adjustedWeight);
      if(lotSize <= 0) return false;
      
      // Calculate stop loss and take profit
      double slPoints, tpPoints;
      CalculateRiskParameters(slPoints, tpPoints);
      
      if(signal > 0) // Buy
      {
         double entryPrice = SymbolInfoDouble(GetSymbol(), SYMBOL_ASK);
         double slPrice = entryPrice - slPoints * Point();
         double tpPrice = entryPrice + tpPoints * Point();
         
         bool success = OpenBuyOrder(lotSize, slPrice, tpPrice);
         if(success) compensationTrades++;
         return success;
      }
      else // Sell
      {
         double entryPrice = SymbolInfoDouble(GetSymbol(), SYMBOL_BID);
         double slPrice = entryPrice + slPoints * Point();
         double tpPrice = entryPrice - tpPoints * Point();
         
         bool success = OpenSellOrder(lotSize, slPrice, tpPrice);
         if(success) compensationTrades++;
         return success;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check for support entry (for SUPPORT role)                       |
   //+------------------------------------------------------------------+
   bool CheckForSupportEntry(double weight = 0.5) override
   {
      // Support role - ใช้ lot size น้อยลง
      return CheckForEntry(weight * 0.6);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate lot size - SMART VERSION                               |
   //+------------------------------------------------------------------+
   double CalculateLotSize(double weight)
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double baseRisk = riskPercent / 100.0;
      
      // Adjust risk based on compensation mode
      if(compensationMode)
      {
         // ในโหมดชดเชย ใช้ risk น้อยลงแต่พยายามทำบ่อย
         baseRisk *= 0.7;
      }
      
      double riskAmount = accountBalance * baseRisk * weight;
      
      double slPoints = 50.0; // ใช้ fix ไว้ก่อน
      double tickValue = SymbolInfoDouble(GetSymbol(), SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(GetSymbol(), SYMBOL_TRADE_TICK_SIZE);
      
      if(slPoints == 0 || tickValue == 0 || tickSize == 0)
         return minLotSize;
      
      double lotSize = riskAmount / (slPoints * Point() * tickValue / tickSize);
      
      // Apply limits
      lotSize = MathMax(minLotSize, MathMin(maxLotSize, lotSize));
      
      // Normalize
      double lotStep = SymbolInfoDouble(GetSymbol(), SYMBOL_VOLUME_STEP);
      lotSize = MathRound(lotSize / lotStep) * lotStep;
      
      return NormalizeDouble(lotSize, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate risk parameters - DYNAMIC                              |
   //+------------------------------------------------------------------+
   void CalculateRiskParameters(double &slPoints, double &tpPoints)
   {
      // Dynamic RR based on market and compensation mode
      double baseSL = 50.0; // points
      double baseRR = 1.2;  // Risk:Reward
      
      if(compensationMode)
      {
         // ในโหมดชดเชย ใช้ tighter stops
         baseSL = 40.0;
         baseRR = 1.5;  // ต้องการ RR ดีขึ้น
      }
      
      // Adjust based on ATR volatility
      double atrPoints = lastATR / Point();
      if(atrPoints > 100) // High volatility
      {
         baseSL *= 1.3;
      }
      else if(atrPoints < 30) // Low volatility
      {
         baseSL *= 0.8;
      }
      
      slPoints = baseSL;
      tpPoints = slPoints * baseRR;
   }
   
   //+------------------------------------------------------------------+
   //| Get portfolio profit (simplified)                                |
   //+------------------------------------------------------------------+
   double GetPortfolioProfit()
   {
      // คำนวณ profit จาก positions ทั้งหมดของ EA นี้
      double totalProfit = 0.0;
      int magic = GetMagicNumber();
      string symbol = GetSymbol();
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magic)
         {
            totalProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
      
      return totalProfit;
   }
   
   //+------------------------------------------------------------------+
   //| Open buy order                                                   |
   //+------------------------------------------------------------------+
   bool OpenBuyOrder(double lotSize, double slPrice, double tpPrice)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = GetSymbol();
      request.volume = lotSize;
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(GetSymbol(), SYMBOL_ASK);
      request.sl = slPrice;
      request.tp = tpPrice;
      request.deviation = 10; // อนุญาต deviation เยอะหน่อย
      request.magic = GetMagicNumber();
      request.comment = "Scalp2 Buy" + (compensationMode ? " [COMP]" : "");
      
      if(OrderSend(request, result))
      {
         lastTradeTime = TimeCurrent();
         totalTrades++;
         Print("Scalp2Enhanced: Buy order opened, Lot: ", lotSize, 
               compensationMode ? " (Compensation Mode)" : "");
         return true;
      }
      
      Print("Scalp2Enhanced: Failed to open buy order, Error: ", GetLastError());
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Open sell order                                                  |
   //+------------------------------------------------------------------+
   bool OpenSellOrder(double lotSize, double slPrice, double tpPrice)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = GetSymbol();
      request.volume = lotSize;
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(GetSymbol(), SYMBOL_BID);
      request.sl = slPrice;
      request.tp = tpPrice;
      request.deviation = 10;
      request.magic = GetMagicNumber();
      request.comment = "Scalp2 Sell" + (compensationMode ? " [COMP]" : "");
      
      if(OrderSend(request, result))
      {
         lastTradeTime = TimeCurrent();
         totalTrades++;
         Print("Scalp2Enhanced: Sell order opened, Lot: ", lotSize,
               compensationMode ? " (Compensation Mode)" : "");
         return true;
      }
      
      Print("Scalp2Enhanced: Failed to open sell order, Error: ", GetLastError());
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Update performance tracking                                      |
   //+------------------------------------------------------------------+
   void UpdatePerformance() override
   {
      double currentProfit = GetCurrentProfit();
      totalProfit += currentProfit;
      
      // Track compensation performance
      if(compensationMode && currentProfit > 0)
      {
         totalCompensated += currentProfit;
         successfulCompensations++;
         
         // Update average
         averageCompensation = totalCompensated / successfulCompensations;
         
         // Check if target met
         if(totalCompensated >= compensationTarget)
         {
            Print("Scalp2Enhanced: Compensation TARGET REACHED! $", totalCompensated);
            compensationMode = false;
            compensationTarget = 0.0;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get current profit from active positions                         |
   //+------------------------------------------------------------------+
   double GetCurrentProfit() override
   {
      double profit = 0.0;
      int magic = GetMagicNumber();
      string symbol = GetSymbol();
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magic)
         {
            profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
      return profit;
   }
   
   //+------------------------------------------------------------------+
   //| Get number of active positions                                   |
   //+------------------------------------------------------------------+
   int GetActivePositions() override
   {
      int count = 0;
      int magic = GetMagicNumber();
      string symbol = GetSymbol();
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == magic)
         {
            count++;
         }
      }
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get strategy statistics                                          |
   //+------------------------------------------------------------------+
   void GetStatistics(double &profit, int &positions, double &winRate) override
   {
      profit = totalProfit;
      positions = GetActivePositions();
      winRate = (totalTrades > 0) ? (double)successfulCompensations / compensationTrades * 100.0 : 0.0;
   }
   
   //+------------------------------------------------------------------+
   //| Get compensation statistics                                      |
   //+------------------------------------------------------------------+
   void GetCompensationStats(double &totalComp, int &successCount, double &avgComp)
   {
      totalComp = totalCompensated;
      successCount = successfulCompensations;
      avgComp = averageCompensation;
   }
   
   //+------------------------------------------------------------------+
   //| Set parameters                                                   |
   //+------------------------------------------------------------------+
   void SetParameters(int macdF = 12, int macdS = 26, int macdSig = 9,
                      int stochKperiod = 14, int stochDperiod = 3,
                      double risk = 0.8, double minLot = 0.01, double maxLot = 0.05)
   {
      macdFast = macdF;
      macdSlow = macdS;
      macdSignal = macdSig;
      stochK = stochKperiod;
      stochD = stochDperiod;
      riskPercent = risk;
      minLotSize = minLot;
      maxLotSize = maxLot;
      
      Print("Scalp2Enhanced parameters updated");
   }
   
   //+------------------------------------------------------------------+
   //| Manage trailing stop                                             |
   //+------------------------------------------------------------------+
   void ManageTrailingStop()
   {
      // Simple trailing stop สำหรับ Scalp2
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetSymbol(i) == GetSymbol() && 
            PositionGetInteger(POSITION_MAGIC) == GetMagicNumber())
         {
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            
            long type = PositionGetInteger(POSITION_TYPE);
            double profitPoints = 0;
            
            if(type == POSITION_TYPE_BUY)
            {
               profitPoints = (currentPrice - openPrice) / Point();
               
               // Trail เมื่อ profit 20 points
               if(profitPoints > 20.0)
               {
                  double newSL = openPrice + 15 * Point();
                  if(newSL > currentSL)
                  {
                     ModifyPosition(ticket, newSL, 0);
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               profitPoints = (openPrice - currentPrice) / Point();
               
               // Trail เมื่อ profit 20 points
               if(profitPoints > 20.0)
               {
                  double newSL = openPrice - 15 * Point();
                  if(newSL < currentSL || currentSL == 0)
                  {
                     ModifyPosition(ticket, newSL, 0);
                  }
               }
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Modify position                                                  |
   //+------------------------------------------------------------------+
   bool ModifyPosition(ulong ticket, double slPrice, double tpPrice)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = GetSymbol();
      if(slPrice > 0) request.sl = slPrice;
      if(tpPrice > 0) request.tp = tpPrice;
      request.magic = GetMagicNumber();
      
      return OrderSend(request, result);
   }
   
   //+------------------------------------------------------------------+
   //| Get last indicator values for debugging                          |
   //+------------------------------------------------------------------+
   void GetLastValues(double &macd, double &stochK, double &stochD, 
                      double &atr, double &volume)
   {
      macd = lastMACD;
      stochK = lastStochK;
      stochD = lastStochD;
      atr = lastATR;
      volume = lastVolume;
   }
   
   //+------------------------------------------------------------------+
   //| Print compensation status                                        |
   //+------------------------------------------------------------------+
   void PrintCompensationStatus()
   {
      string status = "=== Scalp2 Compensation Status ===\n";
      status += "Mode: " + string(compensationMode ? "ACTIVE" : "INACTIVE") + "\n";
      status += "Target: $" + DoubleToString(compensationTarget, 2) + "\n";
      status += "Compensated: $" + DoubleToString(totalCompensated, 2) + "\n";
      status += "Success Rate: " + DoubleToString(averageCompensation, 2) + " per trade\n";
      status += "=================================\n";
      
      Print(status);
   }
};

//+------------------------------------------------------------------+
