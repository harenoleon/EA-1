//+------------------------------------------------------------------+
//|                                               PositionManager.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

#include "..//Core/ProfitUniversal.mqh"
#include "..//Core/MarketRegime.mqh"

// Forward declaration
class CMarketRegime;

//+------------------------------------------------------------------+
//| Class: Centralized Position Manager                              |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   CProfitUniversal* profitUniversal;
   CMarketRegime*    marketRegime;
   
   // Configuration
   double            baseProfitTarget;
   double            riskRewardRatio;
   bool              useMultiLevelTP;
   bool              useDynamicTP;
   bool              useRegimeBasedTP;
   bool              useTrailingStop;
   double            trailingStart;
   double            trailingStep;
   bool              useBreakEven;
   double            breakEvenAt;
   
   bool              isInitialized;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CPositionManager() : profitUniversal(NULL),
                        marketRegime(NULL),
                        baseProfitTarget(50.0),
                        riskRewardRatio(1.5),
                        useMultiLevelTP(true),
                        useDynamicTP(true),
                        useRegimeBasedTP(true),
                        useTrailingStop(true),
                        trailingStart(1.0),
                        trailingStep(0.5),
                        useBreakEven(true),
                        breakEvenAt(1.0),
                        isInitialized(false)
   {
      // สร้าง ProfitUniversal instance
      profitUniversal = new CProfitUniversal();
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CPositionManager()
   {
      if(CheckPointer(profitUniversal) == POINTER_DYNAMIC)
         delete profitUniversal;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize (แบบเต็ม parameters)                                  |
   //+------------------------------------------------------------------+
   void Initialize(CMarketRegime* mr = NULL, 
                   double baseTP = 50.0, 
                   double rr = 1.5,
                   bool multiTP = true,
                   bool dynamicTP = true,
                   bool regimeTP = true,
                   bool trailing = true,
                   double trailStart = 1.0,
                   double trailStep = 0.5,
                   bool breakEven = true,
                   double beAt = 1.0)
   {
      marketRegime = mr;
      baseProfitTarget = baseTP;
      riskRewardRatio = rr;
      useMultiLevelTP = multiTP;
      useDynamicTP = dynamicTP;
      useRegimeBasedTP = regimeTP;
      useTrailingStop = trailing;
      trailingStart = trailStart;
      trailingStep = trailStep;
      useBreakEven = breakEven;
      breakEvenAt = beAt;
      
      // Initialize Profit Universal
      if(profitUniversal != NULL)
      {
         profitUniversal.Initialize(baseProfitTarget, riskRewardRatio, 
                                    useMultiLevelTP, useDynamicTP, useRegimeBasedTP);
         
         if(marketRegime != NULL)
            profitUniversal.SetMarketRegime(marketRegime);
            
         Print("Position Manager initialized");
         Print("Base TP: ", baseProfitTarget, ", RR: ", riskRewardRatio);
      }
      
      isInitialized = true;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize แบบย่อ                                                |
   //+------------------------------------------------------------------+
   void InitializeSimple(CMarketRegime* mr, double baseTP = 50.0, double rr = 1.5)
   {
      // เรียก Initialize แบบเต็มด้วยค่า default อื่นๆ
      Initialize(mr, baseTP, rr, true, true, true, true, 1.0, 0.5, true, 1.0);
   }
   
   //+------------------------------------------------------------------+
   //| Initialize แบบไม่มี market regime                                 |
   //+------------------------------------------------------------------+
   void InitializeSimple(double baseTP = 50.0, double rr = 1.5)
   {
      Initialize(NULL, baseTP, rr, true, true, true, true, 1.0, 0.5, true, 1.0);
   }
   
   //+------------------------------------------------------------------+
   //| Set market regime (แยกจาก Initialize)                           |
   //+------------------------------------------------------------------+
   void SetMarketRegime(CMarketRegime* mr)
   {
      marketRegime = mr;
      
      if(profitUniversal != NULL && marketRegime != NULL)
         profitUniversal.SetMarketRegime(marketRegime);
   }
   
   //+------------------------------------------------------------------+
   //| Set configuration                                                |
   //+------------------------------------------------------------------+
   void SetConfig(double baseTP, double rr, bool multiTP, bool dynamicTP, bool regimeTP)
   {
      baseProfitTarget = baseTP;
      riskRewardRatio = rr;
      useMultiLevelTP = multiTP;
      useDynamicTP = dynamicTP;
      useRegimeBasedTP = regimeTP;
      
      if(profitUniversal != NULL)
      {
         profitUniversal.Initialize(baseProfitTarget, riskRewardRatio, 
                                    useMultiLevelTP, useDynamicTP, useRegimeBasedTP);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Called on every tick                                             |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(!isInitialized) return;
      
      // 1. Check and execute profit targets
      if(profitUniversal != NULL)
         profitUniversal.CheckAndExecuteTargets();
      
      // 2. Update trailing stops
      if(useTrailingStop)
         UpdateTrailingStops();
      
      // 3. Move to break-even
      if(useBreakEven)
         CheckBreakEven();
   }
   
   //+------------------------------------------------------------------+
   //| Manage new position (called by strategies)                       |
   //+------------------------------------------------------------------+
   bool ManageNewPosition(ulong ticket, ENUM_ORDER_TYPE type,
                         double entryPrice, double lotSize,
                         string symbol, string strategyName)
   {
      if(!isInitialized || profitUniversal == NULL) 
      {
         Print("Position Manager not initialized or Profit Universal is NULL");
         return false;
      }
      
      // 1. Calculate stop loss
      double stopLoss = CalculateStopLoss(type, entryPrice, symbol, strategyName);
      
      // 2. Set initial stop loss
      if(!SetInitialStopLoss(ticket, stopLoss))
      {
         Print("Failed to set initial SL for ticket: ", ticket);
         return false;
      }
      
      // 3. Create profit targets
      if(!profitUniversal.CreateProfitTargets(ticket, type, entryPrice, 
                                              stopLoss, lotSize, symbol))
      {
         Print("Failed to create profit targets for ticket: ", ticket);
         return false;
      }
      
      Print("Managed position: Ticket ", ticket, ", Type: ", EnumToString(type),
            ", SL: ", stopLoss, ", Strategy: ", strategyName);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate dynamic stop loss                                      |
   //+------------------------------------------------------------------+
   double CalculateStopLoss(ENUM_ORDER_TYPE type, double entryPrice,
                           string symbol, string strategyName)
   {
      double atrValue = iATR(symbol, PERIOD_H1, 14, 0);
      double stopLoss = 0;
      double atrMultiplier = 1.5; // Default
      
      // Strategy-specific SL multipliers
      if(strategyName == "Scalp1" || strategyName == "Scalp1Enhanced")
      {
         atrMultiplier = 1.5;
      }
      else if(strategyName == "Scalp2" || strategyName == "Scalp2Enhanced")
      {
         atrMultiplier = 1.3;
      }
      else if(strategyName == "Trend" || strategyName == "TrendEnhanced")
      {
         atrMultiplier = 2.0;
      }
      else if(strategyName == "Breakout")
      {
         atrMultiplier = 2.5;
      }
      
      // Adjust based on market regime if available
      if(marketRegime != NULL)
      {
         ENUM_MARKET_REGIME regime = marketRegime.GetCurrentRegime();
         
         switch(regime)
         {
            case EA_REGIME_VOLATILE:
               atrMultiplier *= 1.5; // Wider SL in high volatility
               break;
            case EA_REGIME_RANGING:
               atrMultiplier *= 0.7; // Tighter SL in ranging
               break;
            case EA_REGIME_TREND_UP:
            case EA_REGIME_TREND_DOWN:
               if(strategyName == "Trend" || strategyName == "TrendEnhanced")
                  atrMultiplier *= 1.2; // Wider SL for trend following
               break;
         }
      }
      
      // Calculate final SL price
      if(type == ORDER_TYPE_BUY)
      {
         stopLoss = entryPrice - (atrValue * atrMultiplier);
         // Ensure SL is not too close
         double minDistance = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
         stopLoss = MathMin(stopLoss, entryPrice - minDistance);
      }
      else // ORDER_TYPE_SELL
      {
         stopLoss = entryPrice + (atrValue * atrMultiplier);
         double minDistance = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
         stopLoss = MathMax(stopLoss, entryPrice + minDistance);
      }
      
      return NormalizePrice(symbol, stopLoss);
   }
   
   //+------------------------------------------------------------------+
   //| Set initial stop loss                                            |
   //+------------------------------------------------------------------+
   bool SetInitialStopLoss(ulong ticket, double slPrice)
   {
      if(!PositionSelectByTicket(ticket)) 
      {
         Print("Cannot select position with ticket: ", ticket);
         return false;
      }
      
      double currentSL = PositionGetDouble(POSITION_SL);
      
      // Only modify if different
      if(MathAbs(currentSL - slPrice) > SymbolInfoDouble(_Symbol, SYMBOL_POINT))
      {
         CTrade trade;
         trade.SetExpertMagicNumber(0); // ใช้ magic 0 เพื่อให้ทำงานกับทุก position
         
         if(trade.PositionModify(ticket, slPrice, 0))
         {
            Print("SL set for ticket ", ticket, ": ", slPrice);
            return true;
         }
         else
         {
            Print("PositionModify failed for ticket ", ticket, 
                  ": ", trade.ResultRetcodeDescription());
            return false;
         }
      }
      
      return true; // Already correct or no need to modify
   } 
  
   //+------------------------------------------------------------------+
   //| Update trailing stops for all positions                         |
   //+------------------------------------------------------------------+
   void UpdateTrailingStops()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            UpdateTrailingStopForPosition(ticket);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Update trailing stop for specific position                      |
   //+------------------------------------------------------------------+
   void UpdateTrailingStopForPosition(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket)) return;
      
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      // Calculate new trailing stop
      double newSL = CalculateTrailingStop(type, openPrice, currentPrice, 
                                          currentSL, profit);
      
      // Apply if different
      if(MathAbs(newSL - currentSL) > SymbolInfoDouble(_Symbol, SYMBOL_POINT))
      {
         CTrade trade;
         trade.SetExpertMagicNumber(0);
         
         if(trade.PositionModify(ticket, newSL, 0))
         {
            // Print("Trailing stop updated for ticket ", ticket, ": ", newSL);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate trailing stop price                                    |
   //+------------------------------------------------------------------+
   double CalculateTrailingStop(ENUM_POSITION_TYPE type, double openPrice,
                               double currentPrice, double currentSL,
                               double profit)
   {
      double distanceInPrice = MathAbs(currentPrice - openPrice);
      
      // Convert trailing start to price distance
      double trailStartPrice = trailingStart; // ในหน่วยเงิน
      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(distanceInPrice < trailStartPrice) 
         return currentSL; // Not enough profit to start trailing
      
      double newSL = currentSL;
      double trailStepPrice = trailingStep; // ในหน่วยเงิน
      
      if(type == POSITION_TYPE_BUY)
      {
         double potentialSL = currentPrice - trailStepPrice;
         // Only move SL up, never down
         if(potentialSL > currentSL && potentialSL > openPrice)
            newSL = potentialSL;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double potentialSL = currentPrice + trailStepPrice;
         // Only move SL down, never up
         if(potentialSL < currentSL && potentialSL < openPrice)
            newSL = potentialSL;
      }
      
      return newSL;
   }
   
   //+------------------------------------------------------------------+
   //| Check and move to break-even                                     |
   //+------------------------------------------------------------------+
   void CheckBreakEven()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            if(ShouldMoveToBreakEven(type, openPrice, currentPrice, profit))
            {
               MoveToBreakEven(ticket, type, openPrice);
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if should move to break-even                               |
   //+------------------------------------------------------------------+
   bool ShouldMoveToBreakEven(ENUM_POSITION_TYPE type, double openPrice,
                             double currentPrice, double profit)
   {
      double profitInPrice = MathAbs(currentPrice - openPrice);
      
      return (profitInPrice >= breakEvenAt && profit > 0);
   }
   
   //+------------------------------------------------------------------+
   //| Move stop loss to break-even                                     |
   //+------------------------------------------------------------------+
   void MoveToBreakEven(ulong ticket, ENUM_POSITION_TYPE type, double openPrice)
   {
      double newSL = 0;
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(type == POSITION_TYPE_BUY)
         newSL = openPrice + (10 * point); // Slightly above entry
      else if(type == POSITION_TYPE_SELL)
         newSL = openPrice - (10 * point); // Slightly below entry
      
      
      trade.SetExpertMagicNumber(0);
      
      if(trade.PositionModify(ticket, newSL, 0))
      {
         Print("Moved to break-even: Ticket ", ticket, 
               ", New SL: ", newSL);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Remove profit targets for position (when closed manually)        |
   //+------------------------------------------------------------------+
   void RemoveProfitTargets(ulong ticket)
   {
      if(profitUniversal != NULL)
         profitUniversal->RemoveTargetsForPosition(ticket);
   }
   
   //+------------------------------------------------------------------+
   //| Get profit universal statistics                                  |
   //+------------------------------------------------------------------+
   void GetStats(int &totalHits, int &partialHits, double &totalProfit)
   {
      if(profitUniversal != NULL)
         profitUniversal->GetStats(totalHits, partialHits, totalProfit);
      else
      {
         totalHits = 0;
         partialHits = 0;
         totalProfit = 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Print status                                                     |
   //+------------------------------------------------------------------+
   void PrintStatus()
   {
      if(profitUniversal != NULL)
         profitUniversal->PrintStatus();
   }
   
   //+------------------------------------------------------------------+
   //| Normalize price to symbol digits                                 |
   //+------------------------------------------------------------------+
   double NormalizePrice(string symbol, double price)
   {
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      
      return NormalizeDouble(price, digits);
   }
   
    //+------------------------------------------------------------------+
   //| Check if initialized                                             |
   //+------------------------------------------------------------------+
   bool IsInitialized() const { return isInitialized; }
   
   //+------------------------------------------------------------------+
   //| Get Profit Universal pointer                                     |
   //+------------------------------------------------------------------+
   CProfitUniversal* GetProfitUniversal() { return profitUniversal; }
};
