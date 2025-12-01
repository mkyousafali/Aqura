# URBAN2_2025 Database Access Guide

## Database Connection Details

- **Server IP:** 192.168.0.3
- **Server Name:** WIN-D1D6ENB240A
- **Database Name:** URBAN2_2025
- **Username:** sa
- **Password:** Polosys*123

---

## How to Access Database from VS Code

### 1. Prerequisites
- Python 3.12 (already installed)
- pyodbc library (already installed)

### 2. Connection String Format
```python
server = '192.168.0.3'
database = 'URBAN2_2025'
username = 'sa'
password = 'Polosys*123'

connection_string = f'DRIVER={{SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password};'
```

### 3. Basic Connection Code
```python
import pyodbc

# Connect to database
conn = pyodbc.connect(
    'DRIVER={SQL Server};'
    'SERVER=192.168.0.3;'
    'DATABASE=URBAN2_2025;'
    'UID=sa;'
    'PWD=Polosys*123;'
)

cursor = conn.cursor()

# Execute query
cursor.execute("SELECT * FROM YourTable")
results = cursor.fetchall()

# Close connection
cursor.close()
conn.close()
```

---

## Complete Table List

**Total Tables: 267**

### Main Transaction Tables (High Volume)
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| InvTransactionDetails | 1,495,673 | Sales/Purchase line items |
| InvTransactionDetails2 | 1,455,860 | Alternative transaction details |
| AccTransactionDetails | 605,800 | Accounting transaction details |
| UserActions | 567,889 | User activity log |
| InvTransactionMaster | 203,121 | Sales/Purchase master records |
| AccTransactionMaster | 201,726 | Accounting master records |
| InvTransactionMasterEInvoice | 188,372 | E-Invoice records |
| InvTransactionTaxableDetails | 188,489 | Tax details for invoices |

### Product & Inventory Tables
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| Products | 67,898 | Product master |
| ProductBatches | 67,898 | Product batch information |
| ProductUnits | 73,357 | Product units of measure |
| LastSalesRate | 45,735 | Last sales rate per product |
| SupplierProducts | 28,541 | Supplier-product mapping |
| WarehouseProduct | 14,649 | Warehouse stock |
| VW_DTSTOCK | 14,500 | Stock view |
| StockValuation | 30,081 | Stock valuation records |
| StockValuationResult | 12,371 | Stock valuation results |
| ProductPrices | 4,080 | Product pricing |
| ProductBarcodes | 1,058 | Product barcodes |
| ProductBranchPriceModified | 1,504 | Branch-specific pricing |
| ProductGroups | 42 | Product groups/categories |

### Customer & Supplier Tables
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| PrivilegeCards | 56,119 | Customer loyalty cards |
| VoidItems | 62,039 | Voided items |
| SettlementDetails | 78,900 | Payment settlements |
| Parties | 565 | Customers and suppliers |
| AccLedgers | 828 | Accounting ledgers |

### Sales & Returns Tables
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| InvTransactionMaster | 203,121 | All transactions (SI, SR, GRN, PI, etc.) |
| InvTransactionDetails | 1,495,673 | Transaction line items |
| InvTransactionMoreDetails | 56,522 | Additional transaction info |
| ModifiedTransMasters | 2,857 | Modified transaction records |
| ConvertedSOTransactions | 2,856 | Converted sales orders |

### Configuration & Settings Tables
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| Settings | 753 | System settings |
| Schemes | 501 | Discount/promotion schemes |
| SpecialPriceScheme | 8,026 | Special pricing rules |
| TaxOnExpenses | 496 | Tax configuration |
| BillwiseMaster | 4,849 | Bill-wise accounting |
| PriceChange | 1,636 | Price change history |

### Employee & User Tables
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| Employees | 66 | Employee master |
| Users | 49 | System users |
| UserRights | 1,020 | User permissions |
| UserTypes | 9 | User type categories |
| EmpDesignations | 27 | Employee designations |

### Branch & Location Tables
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| Branch | 5 | Branch locations |
| Warehouses | 17 | Warehouse locations |
| Counter | 8 | Sales counters |
| CounterShift | 1,901 | Counter shift records |

### System & Technical Tables
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| LanguageDictionary | 1,238 | Multi-language support |
| NodeDetails | 91 | System node information |
| Vouchers | 61 | Voucher definitions |
| VoucherTypeName | 104 | Voucher type names |
| InvPrintDetails | 624 | Print configuration |
| TransactionAcceptReject | 576 | Transaction approvals |

### Reference & Master Data Tables
| Table Name | Row Count | Purpose |
|------------|-----------|---------|
| CountryList | 128 | Country master |
| States | 41 | State/province master |
| UnitOfMeasures | 46 | Units of measure |
| FastMoovingKeyboardProducts | 60 | Quick access products |
| TaxCategory | 3 | Tax categories |
| Currencies | 2 | Currency master |
| FinancialYears | 1 | Financial year setup |

### Complete Alphabetical Table List
| Table Name | Row Count |
|------------|-----------|
| AccGroups | 83 |
| AccLedgers | 828 |
| AccLogCloudSync | 0 |
| AccTransactionDetails | 605,800 |
| AccTransactionDetailsForPDC | 0 |
| AccTransactionMaster | 201,726 |
| AccTransactionMasterForPDC | 0 |
| AddonsPurchased | 2 |
| AgingPeriod | 0 |
| ApiSyncStatus | 0 |
| AssetDepartment | 1 |
| AssetDepreciationTransDetails | 0 |
| AssetDepreciationTransMaster | 0 |
| AssetTypes | 4 |
| AttachmentsInfo | 0 |
| Authorization | 1 |
| BarcodeRePrint | 0 |
| BatchCriteria | 9 |
| BenefitsAndDeductions | 0 |
| BillModifiedHistory | 35 |
| BillofMaterialDetails | 3 |
| BillofMaterialMaster | 1 |
| BillwiseDetails | 0 |
| BillwiseMaster | 4,849 |
| Branch | 5 |
| BranchLedgers | 17 |
| BranchPriceSettings | 0 |
| Brands | 3 |
| Centralized_tempCards | 0 |
| CloudBucketInfo | 0 |
| CloudDBBackupInfo | 1 |
| CloudMaxTransIDs | 0 |
| CloudSyncData | 0 |
| CloudSyncStatus | 0 |
| CommandsToBranch | 0 |
| CommunicationChat | 0 |
| CompanyDetails | 1 |
| CompanyHolyDays | 0 |
| CompanyProfile | 2 |
| ConvertedSOTransactions | 2,856 |
| ConvertedTransactions | 1 |
| CookingStatus | 0 |
| CostCentres | 2 |
| Counter | 8 |
| CounterShift | 1,901 |
| CountryList | 128 |
| CreditCardType | 3 |
| Currencies | 2 |
| CustomerSupplierLedger | 0 |
| CustomesTaxDetails | 0 |
| DailyFinishedStocks | 0 |
| DatabaseID | 0 |
| DataStore | 2 |
| DayClose | 0 |
| DayEndSummary | 0 |
| DBVersions | 1 |
| DeliveryLocations | 0 |
| Departments | 0 |
| DiscountOnTotal | 0 |
| E_WayBillDetails | 0 |
| ECOM_PRODUCT | 0 |
| EcomParty | 0 |
| EinvAPIsSyncInfo | 1 |
| EInvoiceIntegrationSettings | 11 |
| EinvoiceLocalStorage | 0 |
| EinvoiceNotificationInfo | 1 |
| EinvoiceSelectedForArchive | 0 |
| EinvSysCodes | 10 |
| EmailList | 0 |
| EmpDailyWageTransactionDetails | 0 |
| EmpDailyWageTransactionMaster | 0 |
| EmpDesignations | 27 |
| EmpDocuments | 0 |
| EmpGradeMaster | 0 |
| EmpGradeTransaction | 0 |
| EmpInOutMaster | 0 |
| EmpInOutTransaction | 0 |
| EmpLoanRecovery | 0 |
| EmpLoanTransaction | 0 |
| EmployeeBenefitsDeducts | 0 |
| EmployeePunches | 0 |
| Employees | 66 |
| EmployeeWorkTimeMangement | 0 |
| ExcessOrShortage | 0 |
| ExchangeRates | 0 |
| ExchangeRates33 | 2 |
| ExternalApiLoginDetails | 0 |
| FastMoovingKeyboardProducts | 60 |
| FeaturesSubscribed | 0 |
| FinancialYears | 1 |
| FixedAssets | 0 |
| FormDesigns | 0 |
| GiftOnBilling | 0 |
| GP_RPT | 0 |
| GRConsolidatetemp | 1 |
| GridDesignDetail | 229 |
| GridDesignMaster | 6 |
| GridPreference | 0 |
| GridViewCols | 0 |
| GridViewDesigns | 2 |
| GroupCategory | 2 |
| HeaderFooter | 1 |
| HideLedgers | 0 |
| HoldItems | 0 |
| InvLogCloudSync | 0 |
| InvMasters | 0 |
| InvoiceDesignTemplates | 0 |
| InvoiceStatus | 0 |
| InvPrintDetails | 624 |
| InvTransAccounts | 0 |
| InvTransactionDetails | 1,495,673 |
| InvTransactionDetails2 | 1,455,860 |
| InvTransactionMaster | 203,121 |
| InvTransactionMaster2 | 0 |
| InvTransactionMaster3 | 0 |
| InvTransactionMasterEInvoice | 188,372 |
| InvTransactionMoreDetails | 56,522 |
| InvTransactionSerials | 4 |
| InvTransactionTaxableDetails | 188,489 |
| InvTransCouponDetails | 0 |
| InvTransInfo | 1 |
| ItemImage | 0 |
| ItemQtyLimit | 0 |
| ItemsForStockTransferTransit | 0 |
| JHMA_Logs | 4 |
| JobTracking | 0 |
| JobTrackInvoiceDetails | 0 |
| JobWorkDetails | 0 |
| JobWorkMaster | 0 |
| JobWorks | 0 |
| KitchenPrint | 0 |
| Kitchens | 0 |
| LanguageDictionary | 1,238 |
| LastSalesRate | 45,735 |
| LeaveEntryDetails | 0 |
| LeaveEntryMaster | 0 |
| LeaveType | 0 |
| LinkedPunchDB | 0 |
| LinkedServers | 1 |
| ListedProductPrice | 0 |
| MailTemplate | 2 |
| MaxTransIDs | 4 |
| MinMaxStockDetails | 26 |
| ModifiedTransMasters | 2,857 |
| MultiFocSchemes | 0 |
| MutiPaymentInfo | 0 |
| NodeDetails | 91 |
| NotificationQueue | 0 |
| NotificationTemplate | 0 |
| OfferProductDetails | 3 |
| OfferProductsMaster | 1 |
| OnlinePaidServices | 0 |
| Optics_details | 0 |
| Parties | 565 |
| PartyCategory | 2 |
| PDAStock | 0 |
| PDCStatus | 0 |
| PDTVerificationStatus | 0 |
| PlanInfo | 3 |
| PriceCategory | 5 |
| PriceChange | 1,636 |
| Printers | 2 |
| PrivilegeCards | 56,119 |
| PrivilegeCardTransaction | 0 |
| ProductBarcodes | 1,058 |
| ProductBatches | 67,898 |
| ProductBranchPriceModified | 1,504 |
| ProductCategory | 4 |
| ProductDescriptions | 0 |
| ProductDetailsForEcom | 0 |
| ProductFlavor | 0 |
| ProductGroups | 42 |
| ProductMoreInfo | 0 |
| ProductNutrients | 0 |
| ProductPrices | 4,080 |
| Products | 67,898 |
| ProductUnits | 73,357 |
| Projects | 0 |
| ProjectSites | 0 |
| QtySlabOfferSettings | 0 |
| QuantityDiscountScheme | 1 |
| RegDetails | 18 |
| RegServer | 1 |
| Remainders | 1 |
| SalaryTransDetails | 0 |
| SalaryTransMaster | 0 |
| salesDetailedEdit | 0 |
| SalesmanIncentiveSettings | 0 |
| SalesManProduct | 0 |
| SalesManRoute | 0 |
| SalesManVisitedShopDetails | 0 |
| SalesReceiptDetails | 0 |
| SalesReceiptMaster | 0 |
| SalesReturnAmountDetails | 0 |
| SalesRoutes | 4 |
| SchemeProducts | 0 |
| Schemes | 501 |
| SecondDisplayImages | 0 |
| Section6 | 0 |
| Sections | 2 |
| SerialLinkedBranches | 13 |
| ServiceProvider | 0 |
| ServiceTrans | 0 |
| Settings | 753 |
| SettlementDetails | 78,900 |
| Shelfs | 0 |
| ShiftMaster | 0 |
| ShortKeys | 0 |
| SittingTables | 5 |
| SMSTemplate | 0 |
| SpecialPriceScheme | 8,026 |
| States | 41 |
| StockAlertDetails | 0 |
| StockAlertMaster | 0 |
| StockDiff | 9,021 |
| StockValuation | 30,081 |
| StockValuationResult | 12,371 |
| SubstituteItems | 0 |
| SupplierProducts | 28,541 |
| SupplyType | 0 |
| SyncSystemCode | 0 |
| SyncTimes | 1 |
| sysdiagrams | 0 |
| TableLocations | 0 |
| TaxCategory | 3 |
| TaxConfig | 0 |
| TaxNames | 0 |
| TaxOnExpenses | 496 |
| TaxProAuthDetails | 0 |
| TaxSlabs | 0 |
| TaxValue | 0 |
| tbEInvoiceInfo | 0 |
| tbEInvoiceInfoDetails | 0 |
| tbEInvoiceInfoMaster | 0 |
| tblVerHistory | 4 |
| TCSCategory | 0 |
| TEMPAVGRATE_table | 9,230 |
| TempFifo | 0 |
| TempFifoBulk | 0 |
| tempFinalRpt | 135 |
| TempIDs | 1 |
| Templates | 0 |
| TICKET | 0 |
| TransactionAcceptReject | 576 |
| TransactionNotification | 0 |
| Tray | 0 |
| UnitOfMeasures | 46 |
| UserActions | 567,889 |
| UserDevicePermissions | 0 |
| UserLedgers | 0 |
| UserMessages | 7 |
| UserPrinter | 0 |
| UserRights | 1,020 |
| Users | 49 |
| UserSettings | 3 |
| UserTypes | 9 |
| Vehicles | 0 |
| VoidItems | 62,039 |
| Vouchers | 61 |
| VoucherTypeName | 104 |
| VW_DTSTOCK | 14,500 |
| WarehouseProduct | 14,649 |
| WarehouseReorderProducts | 0 |
| Warehouses | 17 |
| WarehousesAndEmployees | 0 |
| WarehouseWiseDeliveryList | 0 |
| WhatsappIntegration | 0 |

---

## Important Table Information

### Main Sales Tables
- **InvTransactionMaster** - Sales header/master table
- **InvTransactionDetails** - Sales line items/details table

### Key Voucher Types
- **SI** - Sales Invoice (187,144 records)
- **SR** - Sales Return (1,230 records)
- **GRN** - Goods Receipt Note (3,883 records)
- **PI** - Purchase Invoice (2,905 records)
- **PO** - Purchase Order (1,430 records)

### Important Columns in InvTransactionMaster
- `TransactionDate` - Transaction date
- `VoucherType` - Type of transaction (SI, SR, etc.)
- `GrandTotal` - Final amount
- `VatAmount` - Tax amount
- `TotalGross` - Gross amount before tax
- `TotalDiscount` - Total discount
- `BranchID` - Branch identifier
- `LedgerID` - Customer/Party ledger

### Important Columns in InvTransactionDetails
- `ProductDescription` - Product name
- `Quantity` - Quantity sold
- `NetAmount` - Net amount for item
- `UnitPrice` - Price per unit
- `TotalVatAmount` - Tax on item
- `TotalDiscount` - Discount on item

---

## How to Get Sales After Returns

### Method 1: Using Python Script

Run the provided script:
```bash
python sales_with_returns.py
```

### Method 2: Custom Date Query

**Python Code:**
```python
import pyodbc

# Connection
conn = pyodbc.connect(
    'DRIVER={SQL Server};SERVER=192.168.0.3;'
    'DATABASE=URBAN2_2025;UID=sa;PWD=Polosys*123;'
)
cursor = conn.cursor()

# Set your date
target_date = '2025-11-26'

# Get Sales
cursor.execute("""
    SELECT COUNT(*), SUM(GrandTotal), SUM(VatAmount)
    FROM InvTransactionMaster
    WHERE CAST(TransactionDate AS DATE) = ?
    AND VoucherType = 'SI'
""", target_date)
sales = cursor.fetchone()

# Get Returns
cursor.execute("""
    SELECT COUNT(*), SUM(GrandTotal), SUM(VatAmount)
    FROM InvTransactionMaster
    WHERE CAST(TransactionDate AS DATE) = ?
    AND VoucherType = 'SR'
""", target_date)
returns = cursor.fetchone()

# Calculate Net
net_sales = sales[1] - returns[1]
print(f"Gross Sales: ₹{sales[1]:,.2f}")
print(f"Returns: ₹{returns[1]:,.2f}")
print(f"Net Sales: ₹{net_sales:,.2f}")

conn.close()
```

### Method 3: SQL Query (Run in SSMS)

```sql
-- Sales for a specific date
DECLARE @TargetDate DATE = '2025-11-26'

-- Gross Sales
SELECT 
    'GROSS SALES' AS Type,
    COUNT(*) AS Bills,
    SUM(GrandTotal) AS Amount,
    SUM(VatAmount) AS Tax
FROM InvTransactionMaster
WHERE CAST(TransactionDate AS DATE) = @TargetDate
AND VoucherType = 'SI'

UNION ALL

-- Sales Returns
SELECT 
    'RETURNS' AS Type,
    COUNT(*) AS Bills,
    SUM(GrandTotal) AS Amount,
    SUM(VatAmount) AS Tax
FROM InvTransactionMaster
WHERE CAST(TransactionDate AS DATE) = @TargetDate
AND VoucherType = 'SR'

-- Net Sales Calculation
SELECT 
    'NET SALES' AS Type,
    (SELECT COUNT(*) FROM InvTransactionMaster WHERE CAST(TransactionDate AS DATE) = @TargetDate AND VoucherType = 'SI')
    - (SELECT COUNT(*) FROM InvTransactionMaster WHERE CAST(TransactionDate AS DATE) = @TargetDate AND VoucherType = 'SR') AS Bills,
    (SELECT SUM(GrandTotal) FROM InvTransactionMaster WHERE CAST(TransactionDate AS DATE) = @TargetDate AND VoucherType = 'SI')
    - (SELECT ISNULL(SUM(GrandTotal), 0) FROM InvTransactionMaster WHERE CAST(TransactionDate AS DATE) = @TargetDate AND VoucherType = 'SR') AS Amount,
    (SELECT SUM(VatAmount) FROM InvTransactionMaster WHERE CAST(TransactionDate AS DATE) = @TargetDate AND VoucherType = 'SI')
    - (SELECT ISNULL(SUM(VatAmount), 0) FROM InvTransactionMaster WHERE CAST(TransactionDate AS DATE) = @TargetDate AND VoucherType = 'SR') AS Tax
```

---

## Available Python Scripts

### 1. query_urban_db.py
Lists all tables in the database
```bash
python query_urban_db.py
```

### 2. get_today_sales.py
Shows today's sales summary
```bash
python get_today_sales.py
```

### 3. recent_sales.py
Shows most recent sales with 7-day summary
```bash
python recent_sales.py
```

### 4. sales_with_returns.py
Shows sales after deducting returns for Nov 26, 2025
```bash
python sales_with_returns.py
```

---

## Common Queries

### Get Sales by Date Range
```python
cursor.execute("""
    SELECT 
        CAST(TransactionDate AS DATE) AS Date,
        COUNT(*) AS Bills,
        SUM(GrandTotal) AS Sales
    FROM InvTransactionMaster
    WHERE TransactionDate BETWEEN ? AND ?
    AND VoucherType = 'SI'
    GROUP BY CAST(TransactionDate AS DATE)
    ORDER BY Date DESC
""", start_date, end_date)
```

### Get Top Selling Products
```python
cursor.execute("""
    SELECT TOP 10
        ProductDescription,
        SUM(Quantity) AS TotalQty,
        SUM(NetAmount) AS TotalAmount
    FROM InvTransactionDetails itd
    INNER JOIN InvTransactionMaster itm 
        ON itd.InvTransactionMasterID = itm.InvTransactionMasterID
    WHERE CAST(itm.TransactionDate AS DATE) = ?
    AND itm.VoucherType = 'SI'
    GROUP BY ProductDescription
    ORDER BY SUM(Quantity) DESC
""", target_date)
```

### Get Sales by Branch
```python
cursor.execute("""
    SELECT 
        BranchID,
        COUNT(*) AS Bills,
        SUM(GrandTotal) AS Sales
    FROM InvTransactionMaster
    WHERE CAST(TransactionDate AS DATE) = ?
    AND VoucherType = 'SI'
    GROUP BY BranchID
""", target_date)
```

---

## Important Notes

⚠️ **Safety:**
- All provided scripts are READ-ONLY
- They will NOT modify, delete, or change any data
- Safe to run multiple times

⚠️ **Connection:**
- Server must be accessible at IP 192.168.0.3
- SQL Server Authentication is used (not Windows Auth)
- Firewall must allow connections on SQL Server port

⚠️ **Date Format:**
- Always use format: 'YYYY-MM-DD' (e.g., '2025-11-26')
- Dates are stored in `TransactionDate` column

---

## Troubleshooting

**Cannot connect to database:**
- Verify server is running: `ping 192.168.0.3`
- Check SQL Server service is running
- Verify credentials are correct

**Column not found error:**
- Check column names using: `python check_table_columns.py`
- Refer to the column list above

**No data returned:**
- Check the date format
- Verify VoucherType is correct ('SI' for sales, 'SR' for returns)
- Check if transactions exist for that date

---

## Contact & Support
- Database: URBAN2_2025
- Location: C:\Users\DELL\
- Scripts saved in: C:\Users\DELL\
