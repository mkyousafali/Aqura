import pyodbc
from datetime import datetime

# Connect to database
conn = pyodbc.connect(
    'DRIVER={SQL Server};'
    'SERVER=192.168.0.3;'
    'DATABASE=URBAN2_2025;'
    'UID=sa;'
    'PWD=Polosys*123;'
)

cursor = conn.cursor()

# Get today's date
today = datetime.now().strftime('%Y-%m-%d')
print(f"\n{'='*50}")
print(f"SALES REPORT FOR: {today}")
print(f"{'='*50}\n")

# Get Sales (SI = Sales Invoice)
cursor.execute("""
    SELECT COUNT(*), SUM(GrandTotal), SUM(VatAmount)
    FROM InvTransactionMaster
    WHERE CAST(TransactionDate AS DATE) = ?
    AND VoucherType = 'SI'
""", today)
sales = cursor.fetchone()

# Get Returns (SR = Sales Return)
cursor.execute("""
    SELECT COUNT(*), SUM(GrandTotal), SUM(VatAmount)
    FROM InvTransactionMaster
    WHERE CAST(TransactionDate AS DATE) = ?
    AND VoucherType = 'SR'
""", today)
returns = cursor.fetchone()

# Display results
gross_bills = sales[0] or 0
gross_amount = sales[1] or 0
gross_tax = sales[2] or 0

return_bills = returns[0] or 0
return_amount = returns[1] or 0
return_tax = returns[2] or 0

net_bills = gross_bills - return_bills
net_amount = gross_amount - return_amount
net_tax = gross_tax - return_tax

print(f"GROSS SALES:")
print(f"  Bills: {gross_bills}")
print(f"  Amount: ₹{gross_amount:,.2f}")
print(f"  Tax: ₹{gross_tax:,.2f}")

print(f"\nRETURNS:")
print(f"  Bills: {return_bills}")
print(f"  Amount: ₹{return_amount:,.2f}")
print(f"  Tax: ₹{return_tax:,.2f}")

print(f"\n{'='*50}")
print(f"NET SALES:")
print(f"  Bills: {net_bills}")
print(f"  Amount: ₹{net_amount:,.2f}")
print(f"  Tax: ₹{net_tax:,.2f}")
print(f"{'='*50}\n")

cursor.close()
conn.close()
