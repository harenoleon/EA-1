//+------------------------------------------------------------------+
//|                                              PortfolioManager.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

class PortfolioManager
{
private:
   double         smartCloseTarget;
   int            minPositions;
   double         maxDrawdown;
   
public:
   PortfolioManager() : smartCloseTarget(0), minPositions(0), maxDrawdown(0) {}
   
   void Initialize(double target, int minPos)
   {
      smartCloseTarget = target;
      minPositions = minPos;
      maxDrawdown = -999999;
   }
   
   double GetTotalProfit()
   {
      double totalProfit = 0;
      
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            totalProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
      
      // Update max drawdown
      if(totalProfit < maxDrawdown)
         maxDrawdown = totalProfit;
      
      return totalProfit;
   }
   
   bool ShouldSmartClose()
   {
      double profit = GetTotalProfit();
      int positions = PositionsTotal();
      
      return (profit >= smartCloseTarget && positions >= minPositions);
   }
   
   double GetMaxDrawdown() { return maxDrawdown; }
   
   int GetTotalPositions()
   {
      int count = 0;
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol) count++;
      }
      return count;
   }
};
