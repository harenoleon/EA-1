//+------------------------------------------------------------------+
//|                                               ProfitUniversal.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

#include "MarketRegime.mqh"
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Profit Target Structure                                          |
//+------------------------------------------------------------------+
struct SProfitTarget
{
   ulong           positionTicket;  // ตั๋วตำแหน่ง
   double          targetPrice;     // ราคาเป้าหมาย
   double          targetProfit;    // กำไรที่คาดหวัง
   double          lotSize;         // ขนาดล็อต
   ENUM_ORDER_TYPE orderType;       // ประเภทออเดอร์
   datetime        createdTime;     // เวลาสร้าง
   bool            isActive;        // ยังใช้งานอยู่
   bool            isPartial;       // เป็น TP แบบแบ่งส่วน
   int             targetLevel;     // ระดับของ TP (1, 2, 3...)
};

//+------------------------------------------------------------------+
//| Class: Universal Profit Calculator                               |
//+------------------------------------------------------------------+
class CProfitUniversal
{
private:
   SProfitTarget   profitTargets[100];  // เก็บ TP ทั้งหมด
   int             targetCount;
   
   // Configuration
   double          baseProfitTarget;
   double          riskRewardRatio;
   bool            useMultiTP;         // ใช้ TP แบบหลายระดับ
   bool            useDynamicTP;       // ใช้ TP แบบไดนามิก
   bool            useRegimeBasedTP;   // ปรับ TP ตามสภาพตลาด
   
   // Statistics
   int             totalHits;
   int             partialHits;
   double          totalProfitFromTP;
   
   // Reference to market regime
   CMarketRegime*  marketRegime;
   
   // Trading object (ใช้ชื่อไม่ซ้ำกับ global)
   CTrade          m_trade;
   
public:
   CProfitUniversal() : targetCount(0), baseProfitTarget(50.0), 
                        riskRewardRatio(1.5), useMultiTP(true),
                        useDynamicTP(true), useRegimeBasedTP(true),
                        totalHits(0), partialHits(0), totalProfitFromTP(0),
                        marketRegime(NULL) 
   {
      // Initialize array ด้วยค่า default
      for(int i = 0; i < 100; i++)
      {
         profitTargets[i].positionTicket = 0;
         profitTargets[i].targetPrice = 0;
         profitTargets[i].targetProfit = 0;
         profitTargets[i].lotSize = 0;
         profitTargets[i].orderType = ORDER_TYPE_BUY;
         profitTargets[i].createdTime = 0;
         profitTargets[i].isActive = false;
         profitTargets[i].isPartial = false;
         profitTargets[i].targetLevel = 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Initialize                                                       |
   //+------------------------------------------------------------------+
   void Initialize(double baseTP, double rr = 1.5, bool multiTP = true, 
                   bool dynamicTP = true, bool regimeTP = true)
   {
      baseProfitTarget = baseTP;
      riskRewardRatio = rr;
      useMultiTP = multiTP;
      useDynamicTP = dynamicTP;
      useRegimeBasedTP = regimeTP;
      
      targetCount = 0;
      
      Print("Profit Universal System Initialized");
      Print("Base TP: ", baseTP, ", RR: ", rr, 
            ", Multi-TP: ", multiTP, ", Dynamic: ", dynamicTP);
   }
   
   //+------------------------------------------------------------------+
   //| Set Market Regime Reference                                      |
   //+------------------------------------------------------------------+
   void SetMarketRegime(CMarketRegime* regime)
   {
      marketRegime = regime;
   }
   
   //+------------------------------------------------------------------+
   //| Create Profit Targets for a Position                             |
   //+------------------------------------------------------------------+
   bool CreateProfitTargets(ulong ticket, ENUM_ORDER_TYPE type, 
                           double entryPrice, double stopLoss, 
                           double lotSize, string symbol)
   {
      if(targetCount >= 100) return false;
      
      // ตรวจสอบว่า marketRegime มี method GetCurrentRegime หรือไม่
      ENUM_MARKET_REGIME regime = EA_REGIME_UNCLEAR; // Default value
      
      if(marketRegime != NULL)
      {
         // เรียกใช้ method ที่ถูกต้อง
         regime = marketRegime.GetCurrentRegime();
      }
      
      // คำนวณ ATR (MQL5 syntax)
      double atrValue = 0;
      int atrHandle = iATR(symbol, PERIOD_H1, 14);
      if(atrHandle != INVALID_HANDLE)
      {
         double atrBuffer[];
         ArraySetAsSeries(atrBuffer, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
         {
            atrValue = atrBuffer[0];
         }
         IndicatorRelease(atrHandle);
      }
      
      if(useMultiTP)
      {
         // สร้าง TP หลายระดับ
         CreateMultiLevelTP(ticket, type, entryPrice, stopLoss, 
                           lotSize, symbol, atrValue, regime);
      }
      else
      {
         // สร้าง TP เดี่ยว
         CreateSingleTP(ticket, type, entryPrice, stopLoss, 
                       lotSize, symbol, atrValue, regime);
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create Multi-Level Take Profit                                   |
   //+------------------------------------------------------------------+
   void CreateMultiLevelTP(ulong ticket, ENUM_ORDER_TYPE type,
                          double entryPrice, double stopLoss,
                          double lotSize, string symbol,
                          double atrValue, ENUM_MARKET_REGIME regime)
   {
      // แบ่งล็อตเป็น 3 ส่วน
      double partialLot = lotSize / 3.0;
      
      // TP ระดับ 1: เร็ว, กำไรน้อย
      double tp1 = CalculateTPPrice(type, entryPrice, stopLoss, 
                                    atrValue, regime, 1);
      AddTarget(ticket, tp1, baseProfitTarget * 0.3, 
                partialLot, type, 1, true);
      
      // TP ระดับ 2: ปานกลาง
      double tp2 = CalculateTPPrice(type, entryPrice, stopLoss, 
                                    atrValue, regime, 2);
      AddTarget(ticket, tp2, baseProfitTarget * 0.5, 
                partialLot, type, 2, true);
      
      // TP ระดับ 3: สูง, กำไรมาก
      double tp3 = CalculateTPPrice(type, entryPrice, stopLoss, 
                                    atrValue, regime, 3);
      AddTarget(ticket, tp3, baseProfitTarget, 
                partialLot, type, 3, true);
   }
   
   //+------------------------------------------------------------------+
   //| Create Single Take Profit                                        |
   //+------------------------------------------------------------------+
   void CreateSingleTP(ulong ticket, ENUM_ORDER_TYPE type,
                      double entryPrice, double stopLoss,
                      double lotSize, string symbol,
                      double atrValue, ENUM_MARKET_REGIME regime)
   {
      double tpPrice = CalculateTPPrice(type, entryPrice, stopLoss, 
                                        atrValue, regime, 1);
      AddTarget(ticket, tpPrice, baseProfitTarget, 
                lotSize, type, 1, false);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate TP Price Dynamically                                   |
   //+------------------------------------------------------------------+
   double CalculateTPPrice(ENUM_ORDER_TYPE type, double entryPrice, 
                          double stopLoss, double atrValue,
                          ENUM_MARKET_REGIME regime, int level)
   {
      double baseDistance = 0;
      
      if(stopLoss > 0 && useDynamicTP)
      {
         // ใช้ Risk:Reward Ratio
         double risk = MathAbs(entryPrice - stopLoss);
         baseDistance = risk * riskRewardRatio;
      }
      else
      {
         // ใช้ ATR-based
         baseDistance = atrValue * GetATRMultiplier(regime, level);
      }
      
      // ปรับตามระดับ TP
      double levelMultiplier = GetLevelMultiplier(level);
      baseDistance *= levelMultiplier;
      
      // ปรับตามสภาพตลาด
      if(useRegimeBasedTP && marketRegime != NULL)
      {
         double regimeMultiplier = GetRegimeMultiplier(regime, level);
         baseDistance *= regimeMultiplier;
      }
      
      // คำนวณราคา TP สุดท้าย
      if(type == ORDER_TYPE_BUY)
         return entryPrice + baseDistance;
      else
         return entryPrice - baseDistance;
   }
   
   //+------------------------------------------------------------------+
   //| Get ATR Multiplier based on regime and level                     |
   //+------------------------------------------------------------------+
   double GetATRMultiplier(ENUM_MARKET_REGIME regime, int level)
   {
      double baseMultiplier = 1.0;
      
      // ใช้ EA_ prefix จาก MarketRegime.mqh
      switch(regime)
      {
         case EA_REGIME_TREND_UP:
         case EA_REGIME_TREND_DOWN:
            baseMultiplier = 2.0;
            break;
         case EA_REGIME_BREAKOUT_UP:
         case EA_REGIME_BREAKOUT_DOWN:
            baseMultiplier = 2.5;
            break;
         case EA_REGIME_RANGING:
            baseMultiplier = 1.0;
            break;
         case EA_REGIME_VOLATILE:
            baseMultiplier = 1.5;
            break;
         default:
            baseMultiplier = 1.5;
      }
      
      // Adjust for TP level
      switch(level)
      {
         case 1: return baseMultiplier * 0.5;  // TP1: เร็ว
         case 2: return baseMultiplier * 1.0;  // TP2: ปานกลาง
         case 3: return baseMultiplier * 1.5;  // TP3: ช้าแต่กำไรดี
         default: return baseMultiplier;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get Level Multiplier                                             |
   //+------------------------------------------------------------------+
   double GetLevelMultiplier(int level)
   {
      switch(level)
      {
         case 1: return 1.0;
         case 2: return 1.8;
         case 3: return 3.0;
         default: return 1.0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get Regime Multiplier                                            |
   //+------------------------------------------------------------------+
   double GetRegimeMultiplier(ENUM_MARKET_REGIME regime, int level)
   {
      // ใช้ EA_ prefix จาก MarketRegime.mqh
      switch(regime)
      {
         case EA_REGIME_TREND_UP:
         case EA_REGIME_TREND_DOWN:
            return 1.2;
         case EA_REGIME_BREAKOUT_UP:
         case EA_REGIME_BREAKOUT_DOWN:
            return 1.3;
         case EA_REGIME_RANGING:
            return 0.8;
         case EA_REGIME_VOLATILE:
            return 1.0;
         default:
            return 1.0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Add Target to Array                                              |
   //+------------------------------------------------------------------+
   void AddTarget(ulong ticket, double price, double profit,
                 double lot, ENUM_ORDER_TYPE type, int level, bool partial)
   {
      if(targetCount >= 100) return;
      
      profitTargets[targetCount].positionTicket = ticket;
      profitTargets[targetCount].targetPrice = price;
      profitTargets[targetCount].targetProfit = profit;
      profitTargets[targetCount].lotSize = lot;
      profitTargets[targetCount].orderType = type;
      profitTargets[targetCount].createdTime = TimeCurrent();
      profitTargets[targetCount].isActive = true;
      profitTargets[targetCount].isPartial = partial;
      profitTargets[targetCount].targetLevel = level;
      
      targetCount++;
   }
   
   //+------------------------------------------------------------------+
   //| Check and Execute Profit Targets                                 |
   //+------------------------------------------------------------------+
   void CheckAndExecuteTargets()
   {
      for(int i = 0; i < targetCount; i++)
      {
         if(profitTargets[i].isActive && 
            PositionSelectByTicket(profitTargets[i].positionTicket))
         {
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            bool shouldClose = false;
            
            if(posType == POSITION_TYPE_BUY && 
               currentPrice >= profitTargets[i].targetPrice)
            {
               shouldClose = true;
            }
            else if(posType == POSITION_TYPE_SELL && 
                    currentPrice <= profitTargets[i].targetPrice)
            {
               shouldClose = true;
            }
            
            if(shouldClose)
            {
               ExecuteTargetClose(i);
            }
         }
      }
      
      // Clean up inactive targets
      CleanUpTargets();
   }
   
   //+------------------------------------------------------------------+
   //| Execute Target Close                                             |
   //+------------------------------------------------------------------+
   void ExecuteTargetClose(int targetIndex)
   {
      if(targetIndex < 0 || targetIndex >= targetCount) return;
      
      ulong ticket = profitTargets[targetIndex].positionTicket;
      
      if(profitTargets[targetIndex].isPartial)
      {
         // ปิดบางส่วนของตำแหน่ง
         double volumeToClose = profitTargets[targetIndex].lotSize;
         
         if(m_trade.PositionClosePartial(ticket, volumeToClose))
         {
            double profit = m_trade.ResultProfit();
            totalProfitFromTP += profit;
            
            if(profitTargets[targetIndex].targetLevel < 3)
               partialHits++;
            else
               totalHits++;
            
            Print("Partial TP Hit: Ticket ", ticket, 
                  ", Level ", profitTargets[targetIndex].targetLevel,
                  ", Profit: ", profit);
         }
      }
      else
      {
         // ปิดตำแหน่งทั้งหมด
         if(m_trade.PositionClose(ticket))
         {
            double profit = m_trade.ResultProfit();
            totalProfitFromTP += profit;
            totalHits++;
            
            Print("Full TP Hit: Ticket ", ticket, 
                  ", Profit: ", profit);
         }
      }
      
      profitTargets[targetIndex].isActive = false;
   }
   
   //+------------------------------------------------------------------+
   //| Clean Up Inactive Targets                                        |
   //+------------------------------------------------------------------+
   void CleanUpTargets()
   {
      int newCount = 0;
      SProfitTarget tempArray[100];
      
      for(int i = 0; i < targetCount; i++)
      {
         if(profitTargets[i].isActive || 
            (TimeCurrent() - profitTargets[i].createdTime) < 86400) // ยังไม่เกิน 1 วัน
         {
            tempArray[newCount] = profitTargets[i];
            newCount++;
         }
      }
      
      // Copy back
      for(int i = 0; i < newCount; i++)
      {
         profitTargets[i] = tempArray[i];
      }
      
      targetCount = newCount;
   }
   
   //+------------------------------------------------------------------+
   //| Remove Targets for Position                                      |
   //+------------------------------------------------------------------+
   void RemoveTargetsForPosition(ulong ticket)
   {
      for(int i = 0; i < targetCount; i++)
      {
         if(profitTargets[i].positionTicket == ticket)
         {
            profitTargets[i].isActive = false;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get Statistics                                                   |
   //+------------------------------------------------------------------+
   void GetStats(int &hits, int &partials, double &totalProfit)
   {
      hits = totalHits;
      partials = partialHits;
      totalProfit = totalProfitFromTP;
   }
   
   //+------------------------------------------------------------------+
   //| Get Active Target Count                                          |
   //+------------------------------------------------------------------+
   int GetActiveTargetCount()
   {
      int count = 0;
      for(int i = 0; i < targetCount; i++)
      {
         if(profitTargets[i].isActive) count++;
      }
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Print Status                                                     |
   //+------------------------------------------------------------------+
   void PrintStatus()
   {
      Print("Profit Universal Status:");
      Print("Active Targets: ", GetActiveTargetCount());
      Print("Total Hits: ", totalHits, ", Partial Hits: ", partialHits);
      Print("Total Profit from TP: ", totalProfitFromTP);
   }
};
