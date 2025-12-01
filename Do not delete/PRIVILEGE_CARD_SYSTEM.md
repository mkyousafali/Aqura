# Privilege Card System - Complete Documentation

## Overview
The privilege card system in URBAN2_2025 ERP allows customers to accumulate balance and redeem it for discounts on purchases. The system tracks card details, transactions, and redemption history.

---

## Database Tables

### 1. **PrivilegeCards** (Main Card Storage)
**Location:** URBAN2_2025 database  
**Purpose:** Stores all privilege card information and current balances

**Key Columns:**
- `PrivilegeCardsID` (int) - Primary key, unique card ID
- `CardNumber` (varchar) - Visible card number (e.g., "0559395543")
- `Mobile` (varchar) - Customer mobile number (with country code, e.g., "966559395543")
- `CardBalance` (numeric) - Current available balance in SAR
- `BranchID` (int) - Branch where card was issued/registered
- `CardType` (varchar) - Type of card: "Privilege", "Voucher", "Cash Card", "Gift Card"
- `CardStatus` (varchar) - Status: "Active", "Inactive", "Blocked"
- `CustomerName` (varchar) - Cardholder name
- `CreatedDate` (datetime) - When card was created
- `ModifiedDate` (datetime) - Last modification date
- `IsActive` (bit) - Whether card is currently active

**Total Records:** 56,239 cards across 3 branches

**Important Notes:**
- Same card number can exist in multiple branches (duplicated entries)
- Each branch maintains its own card balance independently
- Card balance is updated automatically when transactions occur

---

### 2. **InvTransactionMaster** (Transaction & Redemption Storage)
**Location:** URBAN2_2025 database  
**Purpose:** Stores all sales transactions including privilege card usage

**Key Columns for Privilege Cards:**
- `InvTransactionMasterID` (varchar) - Primary key, transaction ID
- `VoucherNumber` (varchar) - Visible bill/invoice number
- `TransactionDate` (datetime) - Date of transaction
- `BranchID` (int) - Branch where transaction occurred
- `GrandTotal` (numeric) - Final bill amount after all discounts
- `TotalDiscount` (numeric) - Total discount applied
- `BillDiscount` (numeric) - Bill-level discount amount
- **`PrivCardID` (int)** - Foreign key to PrivilegeCards.PrivilegeCardsID
- **`PrivRedeem` (numeric)** - Amount redeemed/deducted from card balance
- **`PrivAddAmount` (numeric)** - Amount earned/added to card from this purchase
- `VoucherType` (varchar) - Transaction type (usually "SI" for Sales Invoice)
- `PartyName` (varchar) - Customer name on transaction
- `Address4` (varchar) - Often stores mobile number

**Total Transactions with Privilege Cards:** 56,956 records

**Calculation Logic:**
- When customer uses privilege card: `PrivRedeem` = amount deducted
- Customer earns back: `PrivAddAmount` = percentage of GrandTotal (varies by policy)
- Net effect on card: `NewBalance = OldBalance - PrivRedeem + PrivAddAmount`

---

### 3. **InvTransactionDetails** (Transaction Line Items)
**Location:** URBAN2_2025 database  
**Purpose:** Stores individual items/products in each transaction

**Key Columns:**
- `InvTransactionDetailsID` (int) - Primary key
- `InvTransactionMasterID` (varchar) - Foreign key to transaction header
- `ProductID` (int) - Product purchased
- `ProductDescription` (varchar) - Product name/description
- `Quantity` (numeric) - Quantity sold
- `UnitPrice` (numeric) - Price per unit
- `Discount` (numeric) - Discount on this item
- `LineTotal` (numeric) - Total for this line item

---

### 4. **PrivilegeCardTransaction** (Future Use)
**Location:** URBAN2_2025 database  
**Purpose:** Appears to be for points-based redemption system (not currently used)

**Key Columns:**
- `PrivilegeCardTransactionID` (int) - Primary key
- `PrivilegeCardID` (int) - Foreign key to PrivilegeCards
- `PointsRedeem` (numeric) - Points redeemed (currently empty)

**Status:** Table exists but contains no data yet. May be for future points system implementation.

---

## Data Relationships

```
PrivilegeCards (1)
    ↓
    ├── PrivilegeCardsID (PK)
    │
    └── InvTransactionMaster (Many)
            ├── PrivCardID (FK) → References PrivilegeCardsID
            ├── PrivRedeem (Amount deducted)
            └── PrivAddAmount (Amount earned)
                    ↓
                    └── InvTransactionDetails (Many)
                            └── Individual products in transaction
```

---

## How to Query Data

### 1. **Find Card by Number or Mobile**
```sql
SELECT 
    PrivilegeCardsID,
    CardNumber,
    Mobile,
    CustomerName,
    CardBalance,
    BranchID,
    CardType,
    CardStatus
FROM PrivilegeCards
WHERE CardNumber LIKE '%0559395543%' 
   OR Mobile LIKE '%0559395543%'
```

**Expected Result:**
- May return multiple records if card exists in multiple branches
- Each branch has separate balance tracking

---

### 2. **Get Card Redemption History**
```sql
SELECT 
    itm.InvTransactionMasterID,
    itm.VoucherNumber AS BillNumber,
    itm.TransactionDate,
    itm.GrandTotal AS BillAmount,
    itm.PrivRedeem AS AmountRedeemed,
    itm.PrivAddAmount AS AmountEarned,
    itm.BranchID,
    pc.CardNumber,
    pc.CustomerName
FROM InvTransactionMaster itm
INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
WHERE pc.CardNumber = '0559395543'
  AND itm.PrivRedeem IS NOT NULL
  AND itm.PrivRedeem > 0
ORDER BY itm.TransactionDate DESC
```

**Expected Result:**
- All transactions where this card was used to redeem balance
- Shows how much was redeemed and earned in each transaction

---

### 3. **Calculate Total Redemptions for Card**
```sql
SELECT 
    pc.CardNumber,
    pc.CustomerName,
    pc.CardBalance AS CurrentBalance,
    COUNT(itm.InvTransactionMasterID) AS TotalTransactions,
    SUM(itm.PrivRedeem) AS TotalRedeemed,
    SUM(itm.PrivAddAmount) AS TotalEarned,
    MIN(itm.TransactionDate) AS FirstRedemption,
    MAX(itm.TransactionDate) AS LastRedemption
FROM PrivilegeCards pc
LEFT JOIN InvTransactionMaster itm ON pc.PrivilegeCardsID = itm.PrivCardID
WHERE pc.CardNumber = '0559395543'
  AND itm.PrivRedeem > 0
GROUP BY pc.CardNumber, pc.CustomerName, pc.CardBalance
```

**Expected Result:**
- Summary statistics for the card
- Total amount redeemed vs earned
- Date range of usage

---

### 4. **Get Transaction Details with Line Items**
```sql
SELECT 
    itm.VoucherNumber AS BillNumber,
    itm.TransactionDate,
    itm.GrandTotal,
    itm.PrivRedeem,
    itd.ProductDescription,
    itd.Quantity,
    itd.UnitPrice,
    itd.LineTotal
FROM InvTransactionMaster itm
INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
INNER JOIN InvTransactionDetails itd ON itm.InvTransactionMasterID = itd.InvTransactionMasterID
WHERE pc.CardNumber = '0559395543'
  AND itm.PrivRedeem > 0
ORDER BY itm.TransactionDate DESC, itd.InvTransactionDetailsID
```

**Expected Result:**
- Detailed breakdown of what products were purchased
- Shows individual items in each transaction where card was used

---

### 5. **Generate Privilege Card Report (Like ERP Display)**
```sql
SELECT TOP 100
    itm.VoucherNumber AS BillNo,
    CONVERT(varchar, itm.TransactionDate, 103) AS Date,
    itm.GrandTotal AS BillAmount,
    pc.CardNumber,
    itm.PrivAddAmount AS AddAmt,
    itm.PrivRedeem AS Redeem
FROM InvTransactionMaster itm
INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
WHERE itm.PrivCardID IS NOT NULL 
  AND itm.VoucherType = 'SI'
ORDER BY itm.TransactionDate DESC
```

**Expected Result:**
- Report format matching ERP display
- Shows bill number, date, amount, card number, earned amount, redeemed amount
- Date format: DD/MM/YYYY

---

### 6. **Find All Cards with Balances Above Certain Amount**
```sql
SELECT 
    CardNumber,
    Mobile,
    CustomerName,
    CardBalance,
    BranchID,
    CardType
FROM PrivilegeCards
WHERE CardBalance > 50  -- Cards with balance over 50 SAR
  AND CardStatus = 'Active'
  AND IsActive = 1
ORDER BY CardBalance DESC
```

---

### 7. **Update Card Balance (Manual Adjustment)**
```sql
-- Find card IDs first
SELECT PrivilegeCardsID, CardNumber, CardBalance, BranchID
FROM PrivilegeCards
WHERE CardNumber = '0559395543'

-- Update balance (affects ALL branches with this card number)
UPDATE PrivilegeCards
SET CardBalance = 100.00,
    ModifiedDate = GETDATE()
WHERE CardNumber = '0559395543'

-- Verify update
SELECT CardNumber, CardBalance, BranchID, ModifiedDate
FROM PrivilegeCards
WHERE CardNumber = '0559395543'
```

**⚠️ Warning:** This updates balance in ALL branches where card exists!

---

## System Behavior

### Card Creation
1. New card is created in `PrivilegeCards` table
2. Initial balance set (usually 0)
3. Card can be duplicated across multiple branches
4. Each branch maintains independent balance

### Transaction with Redemption
1. Customer presents card at checkout
2. System finds card by `CardNumber` or `Mobile` in `PrivilegeCards`
3. Transaction created in `InvTransactionMaster`:
   - Links to card via `PrivCardID`
   - Records redemption amount in `PrivRedeem`
   - Calculates earned amount in `PrivAddAmount`
4. Card balance automatically updated:
   - `NewBalance = OldBalance - PrivRedeem + PrivAddAmount`

### Multi-Branch Handling
- Same card number can exist in multiple branches
- Each branch has separate `PrivilegeCardsID` and balance
- Transactions are branch-specific
- Card used in Branch 1 affects only Branch 1 balance

---

## Common Queries Use Cases

### Use Case 1: Customer asks "What's my balance?"
```sql
SELECT CardBalance, BranchID
FROM PrivilegeCards
WHERE CardNumber = '0559395543' OR Mobile LIKE '%0559395543%'
```

### Use Case 2: Customer asks "How much have I redeemed?"
```sql
SELECT SUM(PrivRedeem) AS TotalRedeemed
FROM InvTransactionMaster itm
INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
WHERE pc.CardNumber = '0559395543'
```

### Use Case 3: Customer asks "Show my transaction history"
```sql
SELECT 
    VoucherNumber,
    TransactionDate,
    GrandTotal,
    PrivRedeem,
    PrivAddAmount
FROM InvTransactionMaster itm
INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
WHERE pc.CardNumber = '0559395543'
ORDER BY TransactionDate DESC
```

### Use Case 4: Report - Daily redemptions summary
```sql
SELECT 
    CAST(TransactionDate AS DATE) AS Date,
    COUNT(*) AS Transactions,
    SUM(PrivRedeem) AS TotalRedeemed,
    SUM(PrivAddAmount) AS TotalEarned
FROM InvTransactionMaster
WHERE PrivRedeem > 0
  AND TransactionDate >= DATEADD(day, -30, GETDATE())
GROUP BY CAST(TransactionDate AS DATE)
ORDER BY Date DESC
```

---

## Database Statistics

- **Total Privilege Cards:** 56,239
- **Total Transactions with Privilege Cards:** 56,956
- **Card Types:** 4 (Privilege, Voucher, Cash Card, Gift Card)
- **Branches:** 3 active branches
- **Average Transactions per Card:** ~1.01

---

## Important Notes

1. **No Dedicated Report Table:** Reports are generated dynamically via SQL queries, not stored in separate tables

2. **Card Duplication:** Same card number exists in multiple branches with different balances

3. **Balance Calculation:** 
   - Balance decreases by `PrivRedeem` (amount used)
   - Balance increases by `PrivAddAmount` (amount earned)
   - Net effect: `Change = PrivAddAmount - PrivRedeem`

4. **Redemption Rules:**
   - Redemption amounts appear to be in 50 SAR increments (50, 100, 150, etc.)
   - Earned amount typically small percentage of purchase (e.g., 1-2%)

5. **Transaction Linking:** Always join through `PrivCardID` to link cards and transactions

6. **Mobile Number Format:** Stored with country code prefix (966 for Saudi Arabia)

---

## Connection Details

**Database:** URBAN2_2025  
**Server:** 192.168.0.3  
**Authentication:** SQL Server authentication  
**User:** sa  
**Password:** Polosys*123

**Node.js Connection Example:**
```javascript
import sql from 'mssql';

const config = {
  user: 'sa',
  password: 'Polosys*123',
  server: '192.168.0.3',
  database: 'URBAN2_2025',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

const pool = await sql.connect(config);
const result = await pool.request()
  .input('cardNumber', sql.VarChar, '0559395543')
  .query(`
    SELECT * FROM PrivilegeCards 
    WHERE CardNumber = @cardNumber
  `);
```

---

## Example: Complete Card Analysis Script

```javascript
// Get full card analysis
const cardNumber = '0559395543';

// 1. Find card details
const cardInfo = await pool.request().query(`
  SELECT * FROM PrivilegeCards
  WHERE CardNumber = '${cardNumber}'
`);

// 2. Get redemption summary
const summary = await pool.request().query(`
  SELECT 
    COUNT(*) as TotalTransactions,
    SUM(PrivRedeem) as TotalRedeemed,
    SUM(PrivAddAmount) as TotalEarned
  FROM InvTransactionMaster itm
  INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
  WHERE pc.CardNumber = '${cardNumber}'
    AND PrivRedeem > 0
`);

// 3. Get recent transactions
const recent = await pool.request().query(`
  SELECT TOP 10
    VoucherNumber,
    TransactionDate,
    GrandTotal,
    PrivRedeem,
    PrivAddAmount
  FROM InvTransactionMaster itm
  INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
  WHERE pc.CardNumber = '${cardNumber}'
  ORDER BY TransactionDate DESC
`);
```

---

*Document generated: November 27, 2025*  
*Database: URBAN2_2025 ERP System*  
*Version: 1.0*
