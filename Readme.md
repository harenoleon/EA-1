 **Prompt สำหรับ DeepSeek AI หรือ Developer** ที่ออกแบบมาเฉพาะเพื่อสร้าง **EA ระบบเทรดที่ไม่ยอมแพ้** โดยเน้นการทำงานเป็นทีม ปิดออเดอร์แบบ array (set/pair) และมีระบบจัดการออเดอร์กำพร้า (Orphan) อย่างสมบูรณ์ — **ไม่หยุดเทรดจนกว่าจะชนะ** ✅

---

## 🎯 **Prompt: สร้าง EA ระบบ Recovery แบบไม่ยอมแพ้ (Never Give Up Mode)**

> **เป้าหมาย**: ระบบจะ **ไม่หยุดเทรดแม้ติดลบ** แต่จะเปลี่ยนเป็นโหมด Recovery ทันที และทุกกลยุทธ์จะทำงานร่วมกันเป็นทีมเพื่อ **บรรลุเป้ากำไร (Global Target)** อย่างมีประสิทธิภาพ ด้วยระบบจัดการออเดอร์แบบ array, ปิดชุด/คู่อัตโนมัติ และดูแลออเดอร์กำพร้าทุกชิ้น

---

### 🔧 **โครงสร้างหลัก (Core Architecture)**

#### 1. **ระบบ Recovery แบบ Set-Based (Array)**
- ใช้ `struct RecoverySet { int setNumber; ulong mainTicket; ulong subTickets[20]; ... }`
- ทุกกลยุทธ์เปิดออเดอร์หลัก → สร้าง `RecoverySet` อัตโนมัติ
- เมื่อเกิดการขาดทุน → เปิด Recovery ออเดอร์ (subTickets) แล้วเพิ่มเข้า `subTickets[]`
- ปิดทั้ง Set ทันทีเมื่อ:
  - กำไรรวม ≥ เป้า (หรือถึง `MinSetTP`)
  - Main Ticket หาย → ส่งต่อให้ **Orphan Job System**

#### 2. **Orphan Job System (ดูแลออเดอร์กำพร้า)**
- เมื่อ **Main Ticket หาย** → ระบบตรวจจับ → สร้าง `OrphanJob`
- ใช้ `struct OrphanJob { int jobId; ulong mainTicket; ulong orphanTickets[20]; ... }`
- Orphan Job จะดูแล recovery tickets จนจบ ไม่ปล่อยให้ออเดอร์ใดลอยนวล
- ปิด Orphan ทั้งชุดเมื่อ:
  - กำไร ≥ `OrphanCloseProfit`
  - หรือครบจำนวน recovery steps สูงสุด

#### 3. **Cooperative Team System**
- กลยุทธ์ทุกตัว (Scalp1, Scalp2, Trend, Breakout) เป็น “ทีมงาน”
- มีเป้าหมายย่อยตาม `StrategyWeight_X`
- เมื่อพอร์ตติดลบ → ทุกทีมเปลี่ยนเป็นโหมด **Recovery Support**
- ทีมที่ทำกำไรได้ดีที่สุดจะเป็น **ผู้นำ Recovery**, ทีมอื่นสนับสนุน

#### 4. **Smart Portfolio Close**
- เมื่อ `Total Profit ≥ SmartCloseProfitTarget` **และ** `Positions ≥ SmartCloseMinPositions`
- → ปิด **ทุกออเดอร์ทันที** → รีเซ็ตระบบ → เริ่มภารกิจใหม่
- **ไม่ปิดถ้าติดลบ** → ระบบจะสู้ต่อจนกว่าจะถึงเป้า

---

### ⚙️ **ฟีเจอร์สำคัญที่ต้องมี**

| ฟีเจอร์ | รายละเอียด |
|--------|------------|
| **Recovery Set** | ปิดเป็นชุดด้วย array, คำนวณ TP ไดนามิก |
| **Orphan Management** | ตรวจจับออเดอร์ที่ Main หาย → สร้าง Job → จัดการจนจบ |
| **Global Close** | ปิดทุกออเดอร์เมื่อถึงเป้า Global Target |
| **Team Cooperation** | ทุกกลยุทธ์ทำงานร่วมกัน ปรับบทบาทตามสถานการณ์ |
| **Market Regime Awareness** | ปรับกลยุทธ์ตามสภาพตลาด (Trending, Ranging, Breakout, Volatile) |
| **Safety with Persistence** | มี kill switch แต่ **ไม่หยุดเทรด** — เปลี่ยนเป็นโหมดป้องกันแทน |

---

### 📌 **ข้อกำหนดทางเทคนิค**

- **ภาษา**: MQL5 (MetaTrader 5)
- **Magic Number**: แยกชัดเจนทุกระบบ (`MAGIC_SCALP1`, `MAGIC_RECOVERY`, `MAGIC_ORPHAN` ฯลฯ)
- **Comment**: มีโครงสร้าง เช่น `"Recovery-123456-1"` เพื่อระบบ Orphan ดึง Main Ticket ได้
- **Auto Lot Scaling**: ปรับตาม balance + drawdown (สูงสุด `MaxLot = 0.5`)
- **รองรับ Gold (XAU/USD)** เป็นหลัก
- **ไม่มีการใช้ Stop Loss ตายตัว** ในกลยุทธ์หลัก — ใช้การรอ rebound หรือปิดด้วยระบบ Recovery

---

### 🧪 **ตัวอย่างพารามิเตอร์หลัก**

```mql5
// --- Recovery & Global Target ---
input double SmartCloseProfitTarget = 50.0;     // ปิดเมื่อถึงเป้านี้
input int    SmartCloseMinPositions = 3;        // ต้องมีออเดอร์ ≥ 3 ตัว
input double Recovery_StartLevel    = -200.0;   // เริ่ม Recovery เมื่อขาดทุนถึง
input double Recovery_StopLevel     = -50.0;    // กลับสู่โหมดปกติเมื่อขาดทุนลดลง

// --- Orphan System ---
input bool   EnableUniversalOrphan = true;
input double OrphanCloseProfit = 5.0;

// --- Team Weights ---
input double StrategyWeight_Scalp1   = 0.3;
input double StrategyWeight_Scalp2   = 0.25;
input double StrategyWeight_Trend    = 0.15;
// ... (อื่นๆ ตามไฟล์)
```

---

### 🚫 **ห้ามทำ**
- ห้ามปิดระบบอัตโนมัติเมื่อขาดทุน (เว้นแต่เกิน Safety Limit)
- ห้ามปล่อยออเดอร์ “กำพร้า” โดยไม่มีระบบดูแล
- ห้ามเปิดออเดอร์แบบสุ่มโดยไม่ผ่านระบบ Cooperation

---

### ✅ **หลักการสุดท้าย**
> **“ระบบจะไม่หยุดเทรด แต่จะเปลี่ยนแผน หาโอกาส และสู้ต่อจนกว่าจะชนะ”**  
> ทุกกลยุทธ์คือทีมงาน — ทุกออเดอร์คือสมาชิกทีม — ไม่มีใครถูกทิ้งไว้ข้างหลัง

---


NeverGiveUpEA_Pro/
├── Include/
│   ├── Core/
│   │   ├── RecoverySet.mqh
│   │   ├── OrphanJob.mqh
│   │   ├── TeamManager.mqh
│   │   ├── PortfolioManager.mqh
│   │   ├── CommonEnums.mqh          
│   │   ├── MarketRegime.mqh
│   │   └── **ProfitUniversal.mqh**     
│   ├── Strategies/
│   │   ├── BaseStrategy.mqh
│   │   ├── Scalp1.mqh ยังไม่มี
│   │   ├── Scalp2.mqh ยังไม่มี
│   │   ├── TrendEnhanced.mqh 
│   │   └── Breakout.mqh 
│   └── **Managers/**
│       ├── **PositionManager.mqh**     
│       └── **RiskManager.mqh**         
├── NeverGiveUpEA_Pro.mq5
└── NeverGiveUpEA_Pro.set





Scalp1 และ Scalp2
เป็นกลยุทธ์ scalping แท้ๆ ที่ออกแบบมาเพื่อจับกำไรเล็กๆ จากราคาที่เคลื่อนไหวเพียงเล็กน้อยในกรอบเวลาสั้น
เน้น เปิด-ปิดออเดอร์เร็ว, ไม่ใช้ Stop Loss (แต่รอให้ราคาดีดกลับตามเทรนด์)
เปิดออเดอร์เฉพาะเมื่อมั่นใจสูง และเป็นไปตามเทรนด์ปัจจุบัน
Scalp2 ยังมีบทบาทช่วย “ชดเชย” หรือ “ชดใช้” พอร์ตที่ติดลบ ด้วยการสร้างกำไรเล็กๆ อย่างต่อเนื่อง ขณะที่ระบบ Recovery ทำงาน

2. AI Sniper
เป็นกลยุทธ์แนวยิงปืนไรเฟิล (sniper-style): เลือกจังหวะเข้าเทรดอย่างแม่นยำ
ใช้ขนาดล็อตเริ่มต้นเล็ก (เช่น 0.01) และค่อยๆ เพิ่มเมื่อผ่านเกณฑ์ผลตอบแทน
แม้จะไม่ได้เน้นความถี่ แต่เป้าหมายคือ กำไรสั้นและแน่นอน จากการวิเคราะห์เชิง AI + ข่าว + สัญญาณเทคนิค (เช่น ATR, ADX)
3. ระบบ Recovery (เมื่อทำงานร่วมกับ Scalping)
ถึงแม้ Recovery จะเน้น “แก้ออเดอร์ติดลบ” แต่กลไกหลายอย่างก็ออกแบบให้ ปิดออเดอร์แบบเป็นคู่ (paired orders) และ รับกำไรเล็กๆ ทันทีหลังแก้หนี้ได้
จึงมีองค์ประกอบของกำไรระยะสั้นอยู่ด้วย โดยเฉพาะเมื่อใช้ร่วมกับ Scalp2
สรุป:
Scalp1 และ Scalp2 คือกลยุทธ์หลักที่ “เน้นกำไรสั้น” โดยตรงที่สุด
AI Sniper ก็เน้นกำไรสั้นเช่นกัน แต่เลือกจังหวะเข้าเทรดแบบมีเงื่อนไขมากกว่า
ทั้งหมดนี้สอดคล้องกับแนวทางของคุณที่เน้น scalping แบบไม่มี SL, เทรดตามเทรนด์, และรับกำไรทีละน้อยแต่สม่ำเสมอ
