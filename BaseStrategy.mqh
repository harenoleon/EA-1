//+------------------------------------------------------------------+
//|                                               BaseStrategy.mqh    |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

#include <Trade/Trade.mqh>
#include "..//Core/CommonEnums.mqh"

// Forward declarations
class CMarketRegime;
class CPositionManager;

//+------------------------------------------------------------------+
//| Base Strategy Class                                              |
//+------------------------------------------------------------------+
class CBaseStrategy
{
protected:
   // ============ CORE PROPERTIES ============
   string            strategyName;      // ชื่อกลยุทธ์
   ulong             magicNumber;       // เลข magic
   double            weight;            // น้ำหนักกลยุทธ์
   bool              isActive;          // สถานะการทำงาน
   
   // ============ EXTERNAL REFERENCES ============
   CMarketRegime*    marketRegime;      // อ้างอิง market regime
   CPositionManager* positionManager;   // อ้างอิง position manager
   
   // ============ TRADING OBJECTS ============
   CTrade            trade;             // วัตถุเทรด
   
   // ============ PERFORMANCE TRACKING ============
   double            totalProfit;       // กำไรสะสม
   int               winCount;          // นับออเดอร์ชนะ
   int               lossCount;         // นับออเดอร์เสีย
   datetime          lastTradeTime;     // เวลาเทรดล่าสุด
   int               totalTrades;       // จำนวนออเดอร์ทั้งหมด
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CBaseStrategy() : 
      strategyName(""),
      magicNumber(0),
      weight(0.0),
      isActive(true),
      marketRegime(NULL),
      positionManager(NULL),
      totalProfit(0.0),
      winCount(0),
      lossCount(0),
      lastTradeTime(0),
      totalTrades(0)
   {
      // Constructor initialization
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   virtual ~CBaseStrategy()
   {
      // Cleanup if needed
   }
   
   //+------------------------------------------------------------------+
   //| Initialize strategy                                              |
   //+------------------------------------------------------------------+
   virtual void Initialize(string name, ulong magic, double w, CMarketRegime* regime)
   {
      // ตรวจสอบ parameter
      if(name == "")
      {
         Print("Error: Strategy name cannot be empty!");
         return;
      }
      
      strategyName = name;
      magicNumber = magic;
      weight = MathMax(0.0, MathMin(w, 1.0)); // จำกัดค่าระหว่าง 0-1
      
      if(regime != NULL)
      {
         marketRegime = regime;
      }
      
      trade.SetExpertMagicNumber(magicNumber);
      
      Print(strategyName, " initialized: Magic=", magicNumber, 
            ", Weight=", DoubleToString(weight * 100, 1), "%");
   }
   
   //+------------------------------------------------------------------+
   //| Initialize without market regime                                 |
   //+------------------------------------------------------------------+
   virtual void Initialize(string name, ulong magic, double w)
   {
      Initialize(name, magic, w, NULL);
   }
   
   //+------------------------------------------------------------------+
   //| Set Position Manager                                             |
   //+------------------------------------------------------------------+
   void SetPositionManager(CPositionManager* pm)
   {
      if(pm == NULL)
      {
         Print(strategyName, ": Error: Position Manager is NULL!");
         return;
      }
      
      positionManager = pm;
      Print(strategyName, ": Position Manager set successfully");
   }
   
   //+------------------------------------------------------------------+
   //| Set Market Regime                                                |
   //+------------------------------------------------------------------+
   void SetMarketRegime(CMarketRegime* regime)
   {
      if(regime == NULL)
      {
         Print(strategyName, ": Error: Market Regime is NULL!");
         return;
      }
      
      marketRegime = regime;
      Print(strategyName, ": Market Regime set successfully");
   }
   
   //+------------------------------------------------------------------+
   //| Main execution method                                            |
   //+------------------------------------------------------------------+
   virtual void Execute(ENUM_STRATEGY_ROLE role, double portfolioDrawdown) = 0;
   
   //+------------------------------------------------------------------+
   //| Open position with TP/SL management                              |
   //+------------------------------------------------------------------+
   virtual bool OpenPositionWithTP(ENUM_ORDER_TYPE type, double lot, 
                                  string comment = "")
   {
      // ตรวจสอบว่ามี position manager หรือไม่
      if(positionManager == NULL)
      {
         Print(strategyName, ": Error: Position Manager not set!");
         return OpenPositionBasic(type, lot, comment);
      }
      
      // ตรวจสอบสถานะตลาด
      if(!ShouldTrade(type))
      {
         Print(strategyName, ": Market conditions not favorable for trading");
         return false;
      }
      
      // เปิดออเดอร์
      double price = (type == ORDER_TYPE_BUY) ? 
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                     SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      trade.SetExpertMagicNumber(magicNumber);
      
      if(trade.PositionOpen(_Symbol, type, lot, price, 0, 0, comment))
      {
         ulong ticket = trade.ResultOrder();
         double entryPrice = trade.ResultPrice();
         
         Print(strategyName, ": Position opened. Ticket: ", ticket, 
               ", Type: ", EnumToString(type), 
               ", Lot: ", lot, 
               ", Price: ", entryPrice);
         
         // ส่งให้ position manager จัดการ TP/SL - แก้ syntax ตรงนี้!
         bool managed = positionManager.ManageNewPosition(
            ticket,                    // ticket
            type,                      // order type
            entryPrice,                // entry price
            lot,                       // lot size
            _Symbol,                   // symbol
            strategyName               // strategy name
         );
         
         if(managed)
         {
            Print(strategyName, ": Position managed successfully");
            lastTradeTime = TimeCurrent();
            totalTrades++;
            return true;
         }
         else
         {
            Print(strategyName, ": Failed to manage position, closing...");
            trade.PositionClose(ticket);
            return false;
         }
      }
      else
      {
         Print(strategyName, ": Failed to open position. Error: ", 
               trade.ResultRetcodeDescription());
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Basic position open (fallback)                                   |
   //+------------------------------------------------------------------+
   virtual bool OpenPositionBasic(ENUM_ORDER_TYPE type, double lot, string comment = "")
   {
      double price = (type == ORDER_TYPE_BUY) ? 
                     SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                     SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      trade.SetExpertMagicNumber(magicNumber);
      
      if(trade.PositionOpen(_Symbol, type, lot, price, 0, 0, comment))
      {
         ulong ticket = trade.ResultOrder();
         Print(strategyName, ": Basic position opened. Ticket: ", ticket);
         lastTradeTime = TimeCurrent();
         totalTrades++;
         return true;
      }
      
      Print(strategyName, ": Failed to open basic position");
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if should trade                                            |
   //+------------------------------------------------------------------+
   virtual bool ShouldTrade(ENUM_ORDER_TYPE type)
   {
      if(!isActive)
      {
         Print(strategyName, ": Strategy is inactive");
         return false;
      }
      
      // ตรวจสอบ market regime ถ้ามี
      if(marketRegime != NULL)
      {
         // ใช้ method ที่ถูกต้องจาก MarketRegime
         // ใน CommonEnums ใช้ EA_DIRECTION_BULLISH ไม่ใช่ DIRECTION_BULLISH
         // ต้องปรับ method ใน MarketRegime ให้ใช้ ENUM ใหม่
      }
      
      return true; // อนุญาตให้เทรดถ้าไม่มีเงื่อนไขอื่น
   }
   
   //+------------------------------------------------------------------+
   //| Calculate lot size based on role                                 |
   //+------------------------------------------------------------------+
   virtual double CalculateLotSize(ENUM_STRATEGY_ROLE role, double baseLot)
   {
      double multiplier = 1.0;
      
      // ใช้ ENUM จาก CommonEnums (มี EA_ prefix)
      switch(role)
      {
         case EA_ROLE_AGGRESSIVE:
            multiplier = 1.5;
            break;
         case EA_ROLE_SUPPORT:
            multiplier = 0.8;
            break;
         case EA_ROLE_DEFENSIVE:
            multiplier = 0.4;
            break;
      }
      
      double calculatedLot = baseLot * multiplier;
      
      // จำกัดขนาดล็อต
      double maxLot = 0.5; // จาก input parameter
      calculatedLot = MathMin(calculatedLot, maxLot);
      
      // ตรวจสอบ minimum lot
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      calculatedLot = MathMax(calculatedLot, minLot);
      
      // ปัดเศษตาม step
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      calculatedLot = (int)(calculatedLot / lotStep) * lotStep;
      
      return NormalizeDouble(calculatedLot, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Get current profit for this strategy                             |
   //+------------------------------------------------------------------+
   virtual double GetCurrentProfit()
   {
      double profit = 0.0;
      int positions = PositionsTotal();
      
      for(int i = positions - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != _Symbol) continue;
         
         ulong posMagic = PositionGetInteger(POSITION_MAGIC);
         if(posMagic == magicNumber)
         {
            profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
      
      totalProfit = profit;
      return profit;
   }
   
   //+------------------------------------------------------------------+
   //| Get active positions count                                       |
   //+------------------------------------------------------------------+
   virtual int GetActivePositions()
   {
      int count = 0;
      int positions = PositionsTotal();
      
      for(int i = positions - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) != _Symbol) continue;
         
         ulong posMagic = PositionGetInteger(POSITION_MAGIC);
         if(posMagic == magicNumber)
         {
            count++;
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Update performance tracking                                      |
   //+------------------------------------------------------------------+
   virtual void UpdatePerformance()
   {
      GetCurrentProfit(); // อัพเดท totalProfit
      
      // สามารถเพิ่มการนับ win/loss ได้ที่นี่
   }
   
   //+------------------------------------------------------------------+
   //| Get strategy statistics                                          |
   //+------------------------------------------------------------------+
   virtual void GetStats(int &trades, int &wins, int &losses, double &profit)
   {
      trades = totalTrades;
      wins = winCount;
      losses = lossCount;
      profit = totalProfit;
   }
   
   // ============ GETTER METHODS ============
   
   string GetName() const { return strategyName; }
   ulong GetMagicNumber() const { return magicNumber; }
   double GetWeight() const { return weight; }
   bool IsActive() const { return isActive; }
   int GetTotalTrades() const { return totalTrades; }
   double GetTotalProfit() const { return totalProfit; }
   datetime GetLastTradeTime() const { return lastTradeTime; }
   
   // ============ SETTER METHODS ============
   
   void SetActive(bool active) { isActive = active; }
   void SetWeight(double w) { weight = MathMax(0.0, MathMin(w, 1.0)); }
   
   //+------------------------------------------------------------------+
   //| Print strategy status                                            |
   //+------------------------------------------------------------------+
   virtual void PrintStatus()
   {
      string status = StringFormat("%s Status: ", strategyName);
      status += StringFormat("Active=%s, ", isActive ? "Yes" : "No");
      status += StringFormat("Weight=%.1f%%, ", weight * 100);
      status += StringFormat("Magic=%d, ", magicNumber);
      status += StringFormat("Positions=%d, ", GetActivePositions());
      status += StringFormat("Profit=%.2f", GetCurrentProfit());
      
      Print(status);
   }
};
