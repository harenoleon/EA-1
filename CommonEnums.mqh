//+------------------------------------------------------------------+
//|                                              CommonEnums.mqh      |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

// ================ EA-SPECIFIC ENUMS (UNIQUE NAMES) ================

// Strategy Management
enum ENUM_STRATEGY_ROLE
{
   EA_ROLE_AGGRESSIVE = 0,   // เปิดออเดอร์หลัก
   EA_ROLE_SUPPORT    = 1,   // สนับสนุน Recovery
   EA_ROLE_DEFENSIVE  = 2    // ป้องกันความเสี่ยง
};

// Market Analysis
enum ENUM_MARKET_REGIME
{
   EA_REGIME_TREND_UP = 0,        // เทรนด์ขาขึ้นชัดเจน
   EA_REGIME_TREND_DOWN = 1,      // เทรนด์ขาลงชัดเจน
   EA_REGIME_RANGING = 2,         // ไซด์เวย์
   EA_REGIME_BREAKOUT_UP = 3,     // Breakout ขึ้น
   EA_REGIME_BREAKOUT_DOWN = 4,   // Breakout ลง
   EA_REGIME_VOLATILE = 5,        // ความผันผวนสูง
   EA_REGIME_UNCLEAR = 6          // ยังไม่ชัดเจน
};

enum ENUM_MARKET_DIRECTION
{
   EA_DIRECTION_BULLISH = 1,      // มุมมองบวก
   EA_DIRECTION_NEUTRAL = 0,      // มุมมองกลาง
   EA_DIRECTION_BEARISH = -1      // มุมมองลบ
};

// EA Operations
enum ENUM_EA_OPERATION
{
   EA_OP_OPEN_POSITION = 0,
   EA_OP_CLOSE_POSITION = 1,
   EA_OP_MODIFY_POSITION = 2,
   EA_OP_CANCEL_ORDER = 3,
   EA_OP_RECOVERY_START = 4,
   EA_OP_RECOVERY_STOP = 5
};

// Recovery System
enum ENUM_RECOVERY_STATE
{
   EA_RECOVERY_IDLE = 0,
   EA_RECOVERY_ACTIVE = 1,
   EA_RECOVERY_COMPLETED = 2,
   EA_RECOVERY_FAILED = 3,
   EA_RECOVERY_PAUSED = 4
};

// Strategy Types
enum ENUM_STRATEGY_TYPE
{
   EA_STRATEGY_SCALP1 = 0,
   EA_STRATEGY_SCALP2 = 1,
   EA_STRATEGY_TREND = 2,
   EA_STRATEGY_BREAKOUT = 3,
   EA_STRATEGY_RECOVERY = 4
};

// Position Status (EA-specific)
enum ENUM_EA_POSITION_STATUS
{
   EA_POS_ACTIVE = 0,
   EA_POS_CLOSED = 1,
   EA_POS_PENDING = 2,
   EA_POS_RECOVERY = 3,
   EA_POS_ORPHAN = 4
};

// Signal Strength
enum ENUM_SIGNAL_STRENGTH
{
   EA_SIGNAL_WEAK = 0,
   EA_SIGNAL_MEDIUM = 1,
   EA_SIGNAL_STRONG = 2,
   EA_SIGNAL_VERY_STRONG = 3
};

// Risk Level
enum ENUM_RISK_LEVEL
{
   EA_RISK_LOW = 0,
   EA_RISK_MEDIUM = 1,
   EA_RISK_HIGH = 2,
   EA_RISK_EXTREME = 3
};

// Team Cooperation
enum ENUM_TEAM_MODE
{
   TEAM_NORMAL = 0,
   TEAM_RECOVERY = 1,
   TEAM_DEFENSIVE = 2,
   TEAM_AGGRESSIVE = 3
};
