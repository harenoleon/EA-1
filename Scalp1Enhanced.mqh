//+------------------------------------------------------------------+
//|                                               Scalp1Enhanced.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

#include "BaseStrategy.mqh"

//+------------------------------------------------------------------+
//| Enhanced Scalping Strategy 1                                      |
//+------------------------------------------------------------------+
class CScalp1Enhanced : public CBaseStrategy
{
private:
   // Indicators
   int maFastHandle;
   int maSlowHandle;
   int rsiHandle;
   int atrHandle;
   int bbHandle;
   
   // Parameters
   int maFastPeriod;
   int maSlowPeriod;
   int rsiPeriod;
   int atrPeriod;
   int bbPeriod;
   double bbDeviation;
   
   // Entry conditions
   double rsiOverbought;
   double rsiOversold;
   double atrMultiplier;
   double minSpread;
   
   // Risk management
   double riskPercent;
   double profitTarget;
   double stopLossATR;
   bool useTrailingStop;
   double trailingStart;
   double trailingStep;
   
   // Performance tracking

   int winningTrades;
  
   double maxDrawdown;
   
   // State variables
  
   double lastFastMA;
   double lastSlowMA;
   double lastRSI;
   double lastATR;
   double lastUpperBB;
   double lastLowerBB;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CScalp1Enhanced() : 
      maFastHandle(INVALID_HANDLE),
      maSlowHandle(INVALID_HANDLE),
      rsiHandle(INVALID_HANDLE),
      atrHandle(INVALID_HANDLE),
      bbHandle(INVALID_HANDLE),
      maFastPeriod(9),
      maSlowPeriod(21),
      rsiPeriod(14),
      atrPeriod(14),
      bbPeriod(20),
      bbDeviation(2.0),
      rsiOverbought(70),
      rsiOversold(30),
      atrMultiplier(1.5),
      minSpread(2.0),
      riskPercent(1.0),
      profitTarget(15.0),
      stopLossATR(2.0),
      useTrailingStop(true),
      trailingStart(5.0),
      trailingStep(3.0),
      totalTrades(0),
      winningTrades(0),
      totalProfit(0.0),
      maxDrawdown(0.0),
      lastTradeTime(0)
   {
      SetName("Scalp1Enhanced");
      SetType(EA_STRATEGY_SCALP1);
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CScalp1Enhanced()
   {
      if(maFastHandle != INVALID_HANDLE) IndicatorRelease(maFastHandle);
      if(maSlowHandle != INVALID_HANDLE) IndicatorRelease(maSlowHandle);
      if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
      if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
      if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   }
   
   //+------------------------------------------------------------------+
   //| Initialize strategy                                              |
   //+------------------------------------------------------------------+
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int magicNumber) override
   {
      if(!CBaseStrategy::Initialize(symbol, timeframe, magicNumber))
         return false;
      
      // Create indicators
      maFastHandle = iMA(symbol, timeframe, maFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      maSlowHandle = iMA(symbol, timeframe, maSlowPeriod, 0, MODE_SMA, PRICE_CLOSE);
      rsiHandle = iRSI(symbol, timeframe, rsiPeriod, PRICE_CLOSE);
      atrHandle = iATR(symbol, timeframe, atrPeriod);
      bbHandle = iBands(symbol, timeframe, bbPeriod, 0, bbDeviation, PRICE_CLOSE);
      
      if(maFastHandle == INVALID_HANDLE || maSlowHandle == INVALID_HANDLE ||
         rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
         bbHandle == INVALID_HANDLE)
      {
         Print("Failed to create indicators for Scalp1Enhanced");
         return false;
      }
      
      Print("Scalp1Enhanced initialized: ", symbol, " ", EnumToString(timeframe));
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update indicators                                                |
   //+------------------------------------------------------------------+
   void Update() override
   {
      if(!IsInitialized()) return;
      
      double fastMA[2], slowMA[2];
      CopyBuffer(maFastHandle, 0, 0, 2, fastMA);
      CopyBuffer(maSlowHandle, 0, 0, 2, slowMA);
      
      double rsi[2];
      CopyBuffer(rsiHandle, 0, 0, 2, rsi);
      
      double atr[2];
      CopyBuffer(atrHandle, 0, 0, 2, atr);
      
      double upperBB[2], middleBB[2], lowerBB[2];
      CopyBuffer(bbHandle, 1, 0, 2, upperBB); // Upper band
      CopyBuffer(bbHandle, 0, 0, 2, middleBB); // Middle band
      CopyBuffer(bbHandle, 2, 0, 2, lowerBB); // Lower band
      
      lastFastMA = fastMA[1];
      lastSlowMA = slowMA[1];
      lastRSI = rsi[1];
      lastATR = atr[1];
      lastUpperBB = upperBB[1];
      lastLowerBB = lowerBB[1];
      
      // Update performance
      UpdatePerformance();
   }
   
   //+------------------------------------------------------------------+
   //| Check for entry signal (from TeamManager)                        |
   //+------------------------------------------------------------------+
   int CheckSignal() override
   {
      if(!IsInitialized() || !IsActive()) 
         return 0;
      
      // ตรวจสอบเงื่อนไขการเข้าเทรด
      int signal = 0;
      
      // Condition 1: MA Cross
      bool maBullish = lastFastMA > lastSlowMA;
      bool maBearish = lastFastMA < lastSlowMA;
      
      // Condition 2: RSI confirmation
      bool rsiBullish = lastRSI > 50 && lastRSI < rsiOverbought;
      bool rsiBearish = lastRSI < 50 && lastRSI > rsiOversold;
      
      // Condition 3: Bollinger Bands position
      double currentPrice = SymbolInfoDouble(GetSymbol(), SYMBOL_BID);
      bool priceNearLowerBB = currentPrice <= lastLowerBB + (lastATR * 0.5);
      bool priceNearUpperBB = currentPrice >= lastUpperBB - (lastATR * 0.5);
      
      // Condition 4: Time filter (scalping ต้องการการรอ)
      datetime currentTime = TimeCurrent();
      if(currentTime - lastTradeTime < 300) // 5 minutes cooldown
         return 0;
      
      // BUY Signal
      if(maBullish && rsiBullish && priceNearLowerBB)
      {
         // Additional confirmation: Price above middle BB
         if(currentPrice > middleBB[1])
         {
            signal = 1; // Buy signal
         }
      }
      // SELL Signal
      else if(maBearish && rsiBearish && priceNearUpperBB)
      {
         // Additional confirmation: Price below middle BB
         if(currentPrice < middleBB[1])
         {
            signal = -1; // Sell signal
         }
      }
      
      return signal;
   }
   
   //+------------------------------------------------------------------+
   //| Check for entry with weight from TeamManager                     |
   //+------------------------------------------------------------------+
   bool CheckForEntry(double weight = 1.0) override
   {
      int signal = CheckSignal();
      if(signal == 0) return false;
      
      // Adjust lot size based on weight from TeamManager
      double lotSize = CalculateLotSize(weight);
      
      if(lotSize <= 0) return false;
      
      // Calculate stop loss and take profit
      double slPoints = stopLossATR * lastATR / Point();
      double tpPoints = profitTarget / Point();
      
      if(signal > 0) // Buy
      {
         double entryPrice = SymbolInfoDouble(GetSymbol(), SYMBOL_ASK);
         double slPrice = entryPrice - slPoints * Point();
         double tpPrice = entryPrice + tpPoints * Point();
         
         return OpenBuyOrder(lotSize, slPrice, tpPrice);
      }
      else // Sell
      {
         double entryPrice = SymbolInfoDouble(GetSymbol(), SYMBOL_BID);
         double slPrice = entryPrice + slPoints * Point();
         double tpPrice = entryPrice - tpPoints * Point();
         
         return OpenSellOrder(lotSize, slPrice, tpPrice);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check for support entry (for SUPPORT role)                       |
   //+------------------------------------------------------------------+
   bool CheckForSupportEntry(double weight = 0.5) override
   {
      // Support role uses smaller position size
      return CheckForEntry(weight * 0.5);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate lot size based on weight                               |
   //+------------------------------------------------------------------+
   double CalculateLotSize(double weight)
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * (riskPercent / 100.0) * weight;
      
      double stopLossPoints = stopLossATR * lastATR / Point();
      double tickValue = SymbolInfoDouble(GetSymbol(), SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(GetSymbol(), SYMBOL_TRADE_TICK_SIZE);
      
      if(stopLossPoints == 0 || tickValue == 0 || tickSize == 0)
         return 0.0;
      
      double lotSize = riskAmount / (stopLossPoints * Point() * tickValue / tickSize);
      
      // Normalize to broker requirements
      double minLot = SymbolInfoDouble(GetSymbol(), SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(GetSymbol(), SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(GetSymbol(), SYMBOL_VOLUME_STEP);
      
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      lotSize = MathRound(lotSize / lotStep) * lotStep;
      
      return NormalizeDouble(lotSize, 2);
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
      request.deviation = 5;
      request.magic = GetMagicNumber();
      request.comment = GetName() + " Buy";
      
      if(OrderSend(request, result))
      {
         lastTradeTime = TimeCurrent();
         totalTrades++;
         Print("Scalp1Enhanced: Buy order opened, Lot: ", lotSize);
         return true;
      }
      
      Print("Scalp1Enhanced: Failed to open buy order, Error: ", GetLastError());
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
      request.deviation = 5;
      request.magic = GetMagicNumber();
      request.comment = GetName() + " Sell";
      
      if(OrderSend(request, result))
      {
         lastTradeTime = TimeCurrent();
         totalTrades++;
         Print("Scalp1Enhanced: Sell order opened, Lot: ", lotSize);
         return true;
      }
      
      Print("Scalp1Enhanced: Failed to open sell order, Error: ", GetLastError());
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Update performance tracking                                      |
   //+------------------------------------------------------------------+
   void UpdatePerformance() override
{
   double currentProfit = GetCurrentProfit();
   totalProfit += currentProfit; // ← totalProfit มาจาก BaseStrategy
   
   if(currentProfit > 0)
      winningTrades++;
   
   // Update max drawdown (เฉพาะตัวแปรของ Scalp1Enhanced)
   if(currentProfit < 0)
   {
      double drawdown = MathAbs(currentProfit);
      if(drawdown > maxDrawdown)
         maxDrawdown = drawdown;
   }
}
   //+------------------------------------------------------------------+
   //| Get current profit from active positions                         |
   //+------------------------------------------------------------------+
   double GetCurrentProfit() override
   {
      double profit = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == GetSymbol() && 
            PositionGetInteger(POSITION_MAGIC) == GetMagicNumber())
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
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == GetSymbol() && 
            PositionGetInteger(POSITION_MAGIC) == GetMagicNumber())
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
      winRate = (totalTrades > 0) ? (double)winningTrades / totalTrades * 100.0 : 0.0;
   }
   
   //+------------------------------------------------------------------+
   //| Set parameters                                                   |
   //+------------------------------------------------------------------+
   void SetParameters(int fastMA = 9, int slowMA = 21, int rsi = 14, 
                      double rsiOB = 70, double rsiOS = 30,
                      double profit = 15.0, double risk = 1.0,
                      bool trailing = true)
   {
      maFastPeriod = fastMA;
      maSlowPeriod = slowMA;
      rsiPeriod = rsi;
      rsiOverbought = rsiOB;
      rsiOversold = rsiOS;
      profitTarget = profit;
      riskPercent = risk;
      useTrailingStop = trailing;
      
      Print("Scalp1Enhanced parameters updated");
   }
   
   //+------------------------------------------------------------------+
   //| Manage trailing stop                                             |
   //+------------------------------------------------------------------+
   void ManageTrailingStop()
   {
      if(!useTrailingStop) return;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetSymbol(i) == GetSymbol() && 
            PositionGetInteger(POSITION_MAGIC) == GetMagicNumber())
         {
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            long type = PositionGetInteger(POSITION_TYPE);
            
            if(type == POSITION_TYPE_BUY)
            {
               double distance = (currentPrice - openPrice) / Point();
               
               if(distance >= trailingStart)
               {
                  double newSL = openPrice + (trailingStart - trailingStep) * Point();
                  if(newSL > currentSL)
                  {
                     // Modify stop loss
                     ModifyPosition(ticket, newSL, currentTP);
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double distance = (openPrice - currentPrice) / Point();
               
               if(distance >= trailingStart)
               {
                  double newSL = openPrice - (trailingStart - trailingStep) * Point();
                  if(newSL < currentSL || currentSL == 0)
                  {
                     // Modify stop loss
                     ModifyPosition(ticket, newSL, currentTP);
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
      request.sl = slPrice;
      request.tp = tpPrice;
      request.magic = GetMagicNumber();
      
      return OrderSend(request, result);
   }
   
   //+------------------------------------------------------------------+
   //| Get last indicator values for debugging                          |
   //+------------------------------------------------------------------+
   void GetLastValues(double &fastMA, double &slowMA, double &rsi, 
                      double &atr, double &upperBB, double &lowerBB)
   {
      fastMA = lastFastMA;
      slowMA = lastSlowMA;
      rsi = lastRSI;
      atr = lastATR;
      upperBB = lastUpperBB;
      lowerBB = lastLowerBB;
   }
};

//+------------------------------------------------------------------+
