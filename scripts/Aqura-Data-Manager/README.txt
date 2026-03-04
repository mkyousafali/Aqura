╔══════════════════════════════════════════════════════╗
║                                                      ║
║     Aqura ERP Bridge - Data Manager                  ║
║     v2.1 (Updated: March 2026)                       ║
║                                                      ║
╚══════════════════════════════════════════════════════╝

WHAT'S CHANGED IN v2.1:
═══════════════════════

✓ Fixed unit name display for barcodes found in ManualBarcode,
  AutoBarcode, Unit2Barcode, Unit3Barcode columns
  
✓ Price-check now fetches unit names correctly for all barcode
  sources, not just ProductUnits.BarCode


HOW TO USE:
═══════════

1. Copy this ENTIRE folder to the branch server
   (USB drive, shared folder, etc.)

2. Double-click "Setup.bat"

3. Click "Yes" when Windows asks for admin permission

4. The setup handles everything automatically:
   - Installs Node.js (if not installed)
   - Downloads cloudflared tunnel connector
   - Opens the wizard in your browser

5. Fill in the branch info in the wizard and click
   "Install Everything"

6. Done! The branch is connected.


BEFORE YOU START:
═════════════════

You need ONE thing from Cloudflare first:
  → The Tunnel Token (a long string starting with eyJ...)

Get it from:
  https://one.dash.cloudflare.com/
  → Networks → Tunnels → Create a tunnel → copy the token

See the full guide: ERP_BRIDGE_SETUP_GUIDE.md


FILES IN THIS FOLDER:
═════════════════════

  Setup.bat          The main launcher (double-click this)
  setup-wizard.js    The wizard (don't run this directly)
  README.txt         This file


REQUIREMENTS:
═════════════

  ✓ Windows server with SQL Server
  ✓ Internet connection
  ✓ Admin access on the server
  ✓ Cloudflare tunnel token (from dashboard)


https://one.dash.cloudflare.com/1b1a1e30e15c50f03708524125a1094c/networks/connectors