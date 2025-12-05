//+------------------------------------------------------------------+
//|                                           TeamManagerEnhanced.mqh |
//|                                  Copyright 2025, Never Give Up EA |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Never Give Up EA"
#property strict

#include "..//Core/CommonEnums.mqh"
#include "..//Strategies/BaseStrategy.mqh"

// Forward declaration
class CMarketRegime;

//+------------------------------------------------------------------+
//| Enhanced Team Manager with Market Adaptation                     |
//+------------------------------------------------------------------+
class TeamManager
{
private:
   // Strategy management
   CBaseStrategy*   strategies[4];
   double           adaptiveWeights[4];
   double           baseWeights[4];
   
   // Performance tracking
   double           strategyPerformance[4];
   int              strategyPositions[4];
   double           strategyProfit[4];
   
   // Roles
   ENUM_STRATEGY_ROLE currentRoles[4];
   
   // Market regime adaptation
   CMarketRegime*   marketRegime;
   double           regimeMultipliers[7]; // For all 7 regimes
   double           regimeAdaptationSpeed;
   datetime         lastRegimeCheck;
   ENUM_MARKET_REGIME lastRegime;
   
   // Recovery leadership
   int              recoveryLeader;
   double           leaderPerformance;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
       TeamManager() : marketRegime(NULL), 
                         regimeAdaptationSpeed(0.1),
                         recoveryLeader(-1),
                         leaderPerformance(-999999.0)
      {
          // Initialize arrays - FIXED VERSION
          // For pointer arrays
          for(int i = 0; i < ArraySize(strategies); i++)
              strategies[i] = NULL;
          
          // For double arrays
          for(int i = 0; i < ArraySize(adaptiveWeights); i++) {
              adaptiveWeights[i] = 0.0;
              baseWeights[i] = 0.0;
              strategyPerformance[i] = 0.0;
              strategyProfit[i] = 0.0;
              regimeMultipliers[i] = 1.0;
          }
          
          // For int arrays
          for(int i = 0; i < ArraySize(strategyPositions); i++)
              strategyPositions[i] = 0;
          
          // Initialize current roles
          for(int i = 0; i < 4; i++)
              currentRoles[i] = EA_ROLE_AGGRESSIVE;
          
          lastRegimeCheck = 0;
          lastRegime = EA_REGIME_UNCLEAR;
          
          // Set default regime multipliers
          SetDefaultRegimeMultipliers();
      }
   
   //+------------------------------------------------------------------+
   //| Set market regime analyzer                                       |
   //+------------------------------------------------------------------+
   void SetMarketRegime(CMarketRegime* regime)
   {
      if(regime == NULL) return;
      
      marketRegime = regime;
      Print("Team Manager: Market Regime set");
   }
   
   //+------------------------------------------------------------------+
   //| Set base strategy weights                                        |
   //+------------------------------------------------------------------+
   void SetBaseWeights(double scalp1, double scalp2, double trend, double breakout)
   {
      baseWeights[0] = MathMax(0.0, scalp1);
      baseWeights[1] = MathMax(0.0, scalp2);
      baseWeights[2] = MathMax(0.0, trend);
      baseWeights[3] = MathMax(0.0, breakout);
      
      // Normalize to sum to 1
      double sum = baseWeights[0] + baseWeights[1] + baseWeights[2] + baseWeights[3];
      if(sum > 0)
      {
         for(int i = 0; i < 4; i++)
         {
            baseWeights[i] /= sum;
            adaptiveWeights[i] = baseWeights[i]; // Initialize adaptive weights
         }
      }
      
      Print("Team Manager: Base weights set - Scalp1:", DoubleToString(baseWeights[0]*100,1), 
            "%, Scalp2:", DoubleToString(baseWeights[1]*100,1), 
            "%, Trend:", DoubleToString(baseWeights[2]*100,1),
            "%, Breakout:", DoubleToString(baseWeights[3]*100,1), "%");
   }
   
   //+------------------------------------------------------------------+
   //| Register strategy                                                |
   //+------------------------------------------------------------------+
   void RegisterStrategy(int index, CBaseStrategy* strategy)
   {
      if(index < 0 || index >= 4 || strategy == NULL) return;
      
      strategies[index] = strategy;
      
      // Initialize adaptive weight with base weight
      if(index < 4)
         adaptiveWeights[index] = baseWeights[index];
      
      Print("Team Manager: Registered ", strategy.GetName(), " at index ", index);
   }
   
   //+------------------------------------------------------------------+
   //| Set default regime multipliers                                   |
   //+------------------------------------------------------------------+
   void SetDefaultRegimeMultipliers()
   {
      // Higher multipliers for regimes where strategy excels
      // ใช้ EA_ prefix จาก CommonEnums
      regimeMultipliers[EA_REGIME_TREND_UP] = 1.2;      // Trend strategies do well
      regimeMultipliers[EA_REGIME_TREND_DOWN] = 1.2;    // Trend strategies do well
      regimeMultipliers[EA_REGIME_RANGING] = 0.8;       // Scalping strategies do well
      regimeMultipliers[EA_REGIME_BREAKOUT_UP] = 1.0;   // Breakout strategies do well
      regimeMultipliers[EA_REGIME_BREAKOUT_DOWN] = 1.0; // Breakout strategies do well
      regimeMultipliers[EA_REGIME_VOLATILE] = 0.6;      // All strategies reduced
      regimeMultipliers[EA_REGIME_UNCLEAR] = 1.0;       // Neutral
   }
   
   //+------------------------------------------------------------------+
   //| Update adaptive weights based on market regime                   |
   //+------------------------------------------------------------------+
   void UpdateAdaptiveWeights()
   {
      if(marketRegime == NULL || TimeCurrent() - lastRegimeCheck < 60) return;
      
      ENUM_MARKET_REGIME currentRegime = marketRegime.GetCurrentRegime(); // ใช้ . ไม่ใช่ ->
      
      // Update if regime changed
      if(currentRegime != lastRegime)
      {
         Print("Team Manager: Market regime changed to ", GetRegimeString(currentRegime));
         
         // Adjust weights based on regime
         for(int i = 0; i < 4; i++)
         {
            if(strategies[i] != NULL)
            {
               double baseWeight = baseWeights[i];
               double regimeMult = GetStrategyRegimeMultiplier(i, currentRegime);
               
               // Smooth adaptation
               adaptiveWeights[i] = adaptiveWeights[i] * (1.0 - regimeAdaptationSpeed) + 
                                   (baseWeight * regimeMult) * regimeAdaptationSpeed;
               
               // Ensure minimum weight
               adaptiveWeights[i] = MathMax(adaptiveWeights[i], 0.05);
            }
         }
         
         // Normalize weights to sum to 1
         NormalizeWeights();
         
         lastRegime = currentRegime;
      }
      
      lastRegimeCheck = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| Get strategy multiplier for current regime                       |
   //+------------------------------------------------------------------+
   double GetStrategyRegimeMultiplier(int strategyIndex, ENUM_MARKET_REGIME regime)
   {
      if(strategyIndex < 0 || strategyIndex >= 4 || strategies[strategyIndex] == NULL)
         return 1.0;
      
      string strategyName = strategies[strategyIndex].GetName();
      
      // Strategy-specific regime preferences
      // ใช้ EA_ prefix จาก CommonEnums
      if(strategyName == "Trend" || strategyName == "TrendEnhanced")
      {
         if(regime == EA_REGIME_TREND_UP || regime == EA_REGIME_TREND_DOWN)
            return 1.5;
         else if(regime == EA_REGIME_RANGING)
            return 0.5;
      }
      else if(strategyName == "Scalp1" || strategyName == "Scalp1Enhanced")
      {
         if(regime == EA_REGIME_RANGING)
            return 1.3;
         else if(regime == EA_REGIME_VOLATILE)
            return 0.7;
      }
      else if(strategyName == "Scalp2" || strategyName == "Scalp2Enhanced")
      {
         if(regime == EA_REGIME_RANGING)
            return 1.2;
         else if(regime == EA_REGIME_VOLATILE)
            return 0.8;
      }
      else if(strategyName == "Breakout")
      {
         if(regime == EA_REGIME_BREAKOUT_UP || regime == EA_REGIME_BREAKOUT_DOWN)
            return 1.4;
         else if(regime == EA_REGIME_RANGING)
            return 0.8;
      }
      
      return regimeMultipliers[regime];
   }
   
   //+------------------------------------------------------------------+
   //| Normalize weights to sum to 1                                    |
   //+------------------------------------------------------------------+
   void NormalizeWeights()
   {
      double sum = 0.0;
      for(int i = 0; i < 4; i++) 
         sum += adaptiveWeights[i];
      
      if(sum > 0.0 && sum != 1.0)
      {
         for(int i = 0; i < 4; i++) 
            adaptiveWeights[i] /= sum;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Update strategy performance                                      |
   //+------------------------------------------------------------------+
   void UpdateStrategyPerformance()
   {
      for(int i = 0; i < 4; i++)
      {
         if(strategies[i] != NULL)
         {
            strategies[i].UpdatePerformance();
            strategyProfit[i] = strategies[i].GetCurrentProfit();
            strategyPositions[i] = strategies[i].GetActivePositions();
            
            // Calculate performance score (profit normalized by weight)
            if(baseWeights[i] > 0)
               strategyPerformance[i] = strategyProfit[i] / baseWeights[i];
            else
               strategyPerformance[i] = strategyProfit[i];
         }
      }
      
      // Update recovery leader
      UpdateRecoveryLeader();
   }
   
   //+------------------------------------------------------------------+
   //| Update recovery leader                                           |
   //+------------------------------------------------------------------+
   void UpdateRecoveryLeader()
   {
      recoveryLeader = -1;
      leaderPerformance = -999999.0;
      
      for(int i = 0; i < 4; i++)
      {
         if(strategyPerformance[i] > leaderPerformance)
         {
            leaderPerformance = strategyPerformance[i];
            recoveryLeader = i;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get strategy role considering market regime                      |
   //+------------------------------------------------------------------+
   ENUM_STRATEGY_ROLE GetStrategyRole(int strategyIndex, double portfolioDrawdown)
   {
      if(strategyIndex < 0 || strategyIndex >= 4) 
         return EA_ROLE_DEFENSIVE; // ใช้ EA_ prefix
      
      // Recovery mode
      if(portfolioDrawdown < -100.0)
      {
         // In strong trend, adjust roles
         if(marketRegime != NULL && marketRegime.GetTrendStrength() > 0.7)
         {
            string strategyName = strategies[strategyIndex].GetName();
            
            if(strategyName == "Trend" || strategyName == "TrendEnhanced")
               return EA_ROLE_AGGRESSIVE;
            else
               return EA_ROLE_SUPPORT;
         }
         
         // Use performance-based leadership in recovery
         if(strategyIndex == recoveryLeader)
            return EA_ROLE_AGGRESSIVE;
         else
            return EA_ROLE_SUPPORT;
      }
      
      // Normal mode - use adaptive weights
      double weight = adaptiveWeights[strategyIndex];
      
      if(weight >= 0.25)
         return EA_ROLE_AGGRESSIVE;
      else if(weight >= 0.15)
         return EA_ROLE_SUPPORT;
      else
         return EA_ROLE_DEFENSIVE;
   }
   
   //+------------------------------------------------------------------+
   //| Get adaptive weight for strategy                                 |
   //+------------------------------------------------------------------+
   double GetAdaptiveWeight(int strategyIndex)
   {
      if(strategyIndex < 0 || strategyIndex >= 4) return 0.0;
      return adaptiveWeights[strategyIndex];
   }
   
   //+------------------------------------------------------------------+
   //| Get strategy performance                                         |
   //+------------------------------------------------------------------+
   double GetStrategyPerformance(int strategyIndex)
   {
      if(strategyIndex < 0 || strategyIndex >= 4) return 0.0;
      return strategyPerformance[strategyIndex];
   }
   
   //+------------------------------------------------------------------+
   //| Get strategy profit                                              |
   //+------------------------------------------------------------------+
   double GetStrategyProfit(int strategyIndex)
   {
      if(strategyIndex < 0 || strategyIndex >= 4) return 0.0;
      return strategyProfit[strategyIndex];
   }
   
   //+------------------------------------------------------------------+
   //| Get strategy positions count                                     |
   //+------------------------------------------------------------------+
   int GetStrategyPositions(int strategyIndex)
   {
      if(strategyIndex < 0 || strategyIndex >= 4) return 0;
      return strategyPositions[strategyIndex];
   }
   
   //+------------------------------------------------------------------+
   //| Get recovery leader index                                        |
   //+------------------------------------------------------------------+
   int GetRecoveryLeader()
   {
      return recoveryLeader;
   }
   
   //+------------------------------------------------------------------+
   //| Get regime string                                                |
   //+------------------------------------------------------------------+
   string GetRegimeString(ENUM_MARKET_REGIME regime)
   {
      // ใช้ EA_ prefix จาก CommonEnums
      switch(regime)
      {
         case EA_REGIME_TREND_UP:       return "TREND UP";
         case EA_REGIME_TREND_DOWN:     return "TREND DOWN";
         case EA_REGIME_RANGING:        return "RANGING";
         case EA_REGIME_BREAKOUT_UP:    return "BREAKOUT UP";
         case EA_REGIME_BREAKOUT_DOWN:  return "BREAKOUT DOWN";
         case EA_REGIME_VOLATILE:       return "VOLATILE";
         case EA_REGIME_UNCLEAR:        return "UNCLEAR";
         default:                       return "UNKNOWN";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Update all roles based on current conditions                     |
   //+------------------------------------------------------------------+
   void UpdateAllRoles(double portfolioDrawdown)
   {
      for(int i = 0; i < 4; i++)
      {
         currentRoles[i] = GetStrategyRole(i, portfolioDrawdown);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get current role for strategy                                    |
   //+------------------------------------------------------------------+
   ENUM_STRATEGY_ROLE GetCurrentRole(int strategyIndex)
   {
      if(strategyIndex < 0 || strategyIndex >= 4) return EA_ROLE_DEFENSIVE;
      return currentRoles[strategyIndex];
   }
   
   //+------------------------------------------------------------------+
   //| Print team status                                                |
   //+------------------------------------------------------------------+
   void PrintStatus()
   {
      string status = "=== TEAM MANAGER STATUS ===\n";
      
      for(int i = 0; i < 4; i++)
      {
         if(strategies[i] != NULL)
         {
            status += StringFormat("%s: Weight=%.1f%%, Role=%s, Profit=%.2f, Positions=%d\n",
                   strategies[i].GetName(),
                   adaptiveWeights[i] * 100,
                   GetRoleString(currentRoles[i]),
                   strategyProfit[i],
                   strategyPositions[i]);
         }
      }
      
      status += StringFormat("Recovery Leader: %s\n",
             recoveryLeader >= 0 ? strategies[recoveryLeader].GetName() : "None");
      
      if(marketRegime != NULL)
      {
         status += StringFormat("Market Regime: %s\n",
                GetRegimeString(marketRegime.GetCurrentRegime()));
      }
      
      Print(status);
   }
   
   //+------------------------------------------------------------------+
   //| Get role string                                                  |
   //+------------------------------------------------------------------+
   string GetRoleString(ENUM_STRATEGY_ROLE role)
   {
      // ใช้ EA_ prefix จาก CommonEnums
      switch(role)
      {
         case EA_ROLE_AGGRESSIVE: return "AGGRESSIVE";
         case EA_ROLE_SUPPORT:    return "SUPPORT";
         case EA_ROLE_DEFENSIVE:  return "DEFENSIVE";
         default:                 return "UNKNOWN";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Set adaptation speed                                             |
   //+------------------------------------------------------------------+
   void SetAdaptationSpeed(double speed)
   {
      regimeAdaptationSpeed = MathMax(0.01, MathMin(speed, 1.0));
      Print("Team Manager: Adaptation speed set to ", DoubleToString(regimeAdaptationSpeed, 2));
   }
   
   //+------------------------------------------------------------------+
   //| OnTick update                                                    |
   //+------------------------------------------------------------------+
   void OnTick(double portfolioDrawdown)
   {
      // Update adaptive weights
      UpdateAdaptiveWeights();
      
      // Update performance
      UpdateStrategyPerformance();
      
      // Update roles
      UpdateAllRoles(portfolioDrawdown);
   }
};
