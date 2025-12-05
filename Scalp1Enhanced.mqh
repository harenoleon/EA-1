//+------------------------------------------------------------------+
//|                                               Scalp1Enhanced.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

#include "BaseStrategy.mqh"

class CScalp1Enhanced : public CBaseStrategy
{
private:
   // Scalping parameters
   double scalpRangePips;
   double quickProfitTarget;
   double maxLossPips;
   int    maxHoldingBars;
   
   // Indicators
   double emaFast;
   double emaSlow;
   double bollingerUpper;
   double bollingerLower;
   double bollingerMiddle;
   double stochasticMain;
   double stochasticSignal;
   
   // Recovery mode
   bool   isInRecoveryMode;
   double recoveryAggressiveness;
   
public:
   CScalp1Enhanced() : scalpRangePips(3.0), 
                       quickProfitTarget(1.5),
                       maxLossPips(5.0),
                       maxHoldingBars(10),
                       emaFast(0), emaSlow(0),
                       bollingerUpper(0), bollingerLower(0), 
                       bollingerMiddle(0),
                       stochasticMain(0), stochasticSignal(0),
                       isInRecoveryMode(false),
                       recoveryAggressiveness(1.0) {}
   
   void Execute(ENUM_STRATEGY_ROLE role, double portfolioDrawdown) override
   {
      UpdateMarketData();
      isInRecoveryMode = (portfolioDrawdown < -100);
      
      if(isInRecoveryMode)
         recoveryAggressiveness = 1.0 + (MathAbs(portfolioDrawdown) / 500.0);
      
      switch(role)
      {
         case ROLE_AGGRESSIVE:
            ExecuteAggressiveMode();
            break;
         case ROLE_SUPPORT:
            ExecuteSupportMode(portfolioDrawdown);
            break;
         case ROLE_DEFENSIVE:
            ExecuteDefensiveMode();
            break;
      }
   }
   
private:
   void UpdateMarketData()
   {
      emaFast = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 0);
      emaSlow = iMA(_Symbol, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE, 0);
      // ... อื่นๆ
   }
   
   void ExecuteAggressiveMode()
   {
      // Scalping logic
      if(CheckBuySignal())
      {
         double lot = CalculateLotSize(ROLE_AGGRESSIVE, 0.01);
         OpenPositionWithTP(ORDER_TYPE_BUY, lot, "Scalp1-Aggressive");
      }
      // ... Sell signal
   }
   
   // ... method อื่นๆ
};
