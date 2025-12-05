//+------------------------------------------------------------------+
//|                                                     OrphanJob.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

class COrphanJob
{
private:
   int            jobId;
   ulong          originalMainTicket;
   ulong          orphanTickets[20];
   int            orphanCount;
   datetime       createdTime;
   double         closeProfitTarget;
   ulong          recoveryMagic;
   string         comment;
   
public:
   COrphanJob() : jobId(0), originalMainTicket(0), orphanCount(0), closeProfitTarget(0), recoveryMagic(0) {}
   
   void Initialize(int id, ulong mainTicket, double target, ulong magic, string comm="")
   {
      jobId = id;
      originalMainTicket = mainTicket;
      orphanCount = 0;
      createdTime = TimeCurrent();
      closeProfitTarget = target;
      recoveryMagic = magic;
      comment = comm + "-Orphan-" + IntegerToString(jobId);
      ArrayInitialize(orphanTickets, 0);
   }
   
   bool AddOrphanTicket(ulong ticket)
   {
      if(orphanCount >= 20) return false;
      orphanTickets[orphanCount++] = ticket;
      return true;
   }
   
   double CalculateJobProfit()
   {
      double totalProfit = 0;
      for(int i = 0; i < orphanCount; i++)
      {
         if(PositionSelectByTicket(orphanTickets[i]))
         {
            totalProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
      return totalProfit;
   }
   
   bool ShouldCloseJob()
   {
      return CalculateJobProfit() >= closeProfitTarget;
   }
   
   void CloseAllTickets()
   {
      for(int i = 0; i < orphanCount; i++)
      {
         if(PositionSelectByTicket(orphanTickets[i]))
         {
            CTrade trade;
            trade.PositionClose(orphanTickets[i]);
         }
      }
   }
   
   bool HasExpired(int maxHours = 24)
   {
      return (TimeCurrent() - createdTime) > (maxHours * 3600);
   }
   
   int GetOrphanCount() { return orphanCount; }
   int GetJobId() { return jobId; }
   ulong GetOriginalMain() { return originalMainTicket; }
};
