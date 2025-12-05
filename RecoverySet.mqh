//+------------------------------------------------------------------+
//|                                                  RecoverySet.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

//+------------------------------------------------------------------+
//| Structure: Recovery Set                                          |
//+------------------------------------------------------------------+
struct RecoverySet
{
   int           setNumber;
   ulong         mainTicket;
   ulong         subTickets[20];
   int           subCount;
   datetime      createdTime;
   double        targetProfit;
   bool          isOrphan;
   ulong         magicNumber;
   string        symbol;
   
   void Initialize(int sn, ulong mt, double tp, ulong magic, string sym)
   {
      setNumber = sn;
      mainTicket = mt;
      subCount = 0;
      createdTime = TimeCurrent();
      targetProfit = tp;
      isOrphan = false;
      magicNumber = magic;
      symbol = sym;
      ArrayInitialize(subTickets, 0);
   }
   
   bool AddSubTicket(ulong ticket)
   {
      if(subCount >= 20) return false;
      subTickets[subCount++] = ticket;
      return true;
   }
   
   double CalculateSetProfit()
   {
      double totalProfit = 0;
      
      // Check main ticket
      if(PositionSelectByTicket(mainTicket))
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      
      // Check sub tickets
      for(int i = 0; i < subCount; i++)
      {
         if(PositionSelectByTicket(subTickets[i]))
            totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
      
      return totalProfit;
   }
   
   bool ShouldCloseSet(double minSetTP)
   {
      return CalculateSetProfit() >= minSetTP;
   }
   
   void CloseAllTickets()
   {
      // Close sub tickets first
      for(int i = 0; i < subCount; i++)
      {
         if(PositionSelectByTicket(subTickets[i]))
         {
            CTrade trade;
            trade.PositionClose(subTickets[i]);
         }
      }
      
      // Close main ticket
      if(PositionSelectByTicket(mainTicket))
      {
         CTrade trade;
         trade.PositionClose(mainTicket);
      }
   }
};
