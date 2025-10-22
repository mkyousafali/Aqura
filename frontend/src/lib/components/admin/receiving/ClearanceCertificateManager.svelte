<!-- ClearanceCertificateManager.svelte -->
<script>
  import { createEventDispatcher, onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { currentUser } from '$lib/utils/persistentAuth';
  
  export let receivingRecord = null;
  export let show = false;
  
  const dispatch = createEventDispatcher();
  
  let isGenerating = false;
  let isUploading = false;
  let generationError = '';
  let generationSuccess = '';
  let clearanceCertificateUrl = '';
  let uploadProgress = 0;
  let generatedTasks = [];
  let tasksGenerated = false;
  let tasksSummary = null;
  
  // New workflow states
  let certificateGenerated = false;
  let certificateHtml = '';
  let certificateSaved = false;
  let certificateImageUrl = '';
  
  // Generate clearance certificate template (professional template)
  async function generateClearanceCertificateDocument() {
    try {
      isGenerating = true;
      generationError = '';
      
      // Fetch branch name if not available
      let branchName = receivingRecord.branch_name || receivingRecord.branches?.name_en || receivingRecord.branch?.name_en;
      
      if (!branchName && receivingRecord.branch_id) {
        try {
          const { data: branchData, error: branchError } = await supabase
            .from('branches')
            .select('name_en, name_ar')
            .eq('id', receivingRecord.branch_id)
            .single();
            
          if (!branchError && branchData) {
            branchName = branchData.name_en; // Use English name, could also use name_ar for Arabic
          }
        } catch (error) {
          console.error('Error fetching branch name:', error);
        }
      }
      
      // Fallback to showing branch ID if name is still not available
      if (!branchName) {
        branchName = receivingRecord.branch_id ? `Branch ID: ${receivingRecord.branch_id}` : 'Unknown Branch';
      }
      
      // Get vendor information including salesman details
      let vendorName = 'Unknown Vendor';
      let salesmanName = 'Not Assigned';
      let salesmanContact = 'Not Available';
      
      if (receivingRecord.vendor_id && receivingRecord.branch_id) {
        try {
          const { data: vendorData, error: vendorError } = await supabase
            .from('vendors')
            .select('vendor_name, salesman_name, salesman_contact')
            .eq('erp_vendor_id', receivingRecord.vendor_id)
            .eq('branch_id', receivingRecord.branch_id)
            .single();

          if (!vendorError && vendorData) {
            vendorName = vendorData.vendor_name || 'Unknown Vendor';
            salesmanName = vendorData.salesman_name || 'Not Assigned';
            salesmanContact = vendorData.salesman_contact || 'Not Available';
          }
        } catch (error) {
          console.error('Error fetching vendor information:', error);
        }
      }

      // Create clearance certificate data
      const certificateData = {
        receiving_record_id: receivingRecord.id,
        bill_date: receivingRecord.bill_date,
        bill_number: receivingRecord.bill_number || 's545',
        bill_amount: receivingRecord.bill_amount,
        payment_method: receivingRecord.payment_method || 'N/A',
        vendor_name: vendorName,
        branch_name: branchName,
        generated_by: $currentUser?.username || 'Unknown User',
        generated_at: new Date().toISOString(),
        certificate_number: `CLR-${receivingRecord.id.substring(0, 8).toUpperCase()}-${Date.now()}`,
        current_date: new Date().toLocaleDateString('en-US', { 
          year: 'numeric', 
          month: 'long', 
          day: 'numeric' 
        }),
        // Returns data with individual document info
        expired_return_amount: receivingRecord.expired_return_amount || 0,
        expired_erp_document_type: receivingRecord.expired_erp_document_type || 'N/A',
        expired_erp_document_number: receivingRecord.expired_erp_document_number || 'N/A',
        expired_vendor_document_number: receivingRecord.expired_vendor_document_number || 'N/A',
        
        near_expiry_return_amount: receivingRecord.near_expiry_return_amount || 0,
        near_expiry_erp_document_type: receivingRecord.near_expiry_erp_document_type || 'N/A',
        near_expiry_erp_document_number: receivingRecord.near_expiry_erp_document_number || 'N/A',
        near_expiry_vendor_document_number: receivingRecord.near_expiry_vendor_document_number || 'N/A',
        
        over_stock_return_amount: receivingRecord.over_stock_return_amount || 0,
        over_stock_erp_document_type: receivingRecord.over_stock_erp_document_type || 'N/A',
        over_stock_erp_document_number: receivingRecord.over_stock_erp_document_number || 'N/A',
        over_stock_vendor_document_number: receivingRecord.over_stock_vendor_document_number || 'N/A',
        
        damage_return_amount: receivingRecord.damage_return_amount || 0,
        damage_erp_document_type: receivingRecord.damage_erp_document_type || 'N/A',
        damage_erp_document_number: receivingRecord.damage_erp_document_number || 'N/A',
        damage_vendor_document_number: receivingRecord.damage_vendor_document_number || 'N/A',
        
        total_return_amount: receivingRecord.total_return_amount || 0,
        final_bill_amount: receivingRecord.final_bill_amount || receivingRecord.bill_amount,
        // Personnel data - using fetched vendor information
        salesman_name: salesmanName,
        salesman_contact: salesmanContact
      };
      
      // Create professional HTML certificate template matching the exact format required
      const certificateHTML = `
<!DOCTYPE html>
<html dir="ltr" lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Clearance Certificate - ${certificateData.certificate_number}</title>
    <style>
        @page { 
            margin: 20mm; 
            size: A4; 
        }
        body { 
            font-family: 'Arial', sans-serif; 
            margin: 0; 
            padding: 5mm;
            background: white;
            color: #333;
            line-height: 1.1;
            font-size: 12px;
        }
        .certificate-container {
            width: 190mm;
            max-width: 190mm;
            margin: 0 auto;
            background: white;
            padding: 5mm;
            box-sizing: border-box;
        }
        .logo-container {
            text-align: center;
            margin-bottom: 8mm;
        }
        .logo {
            width: 50px;
            height: 35px;
            border: 2px solid #ff6600;
            border-radius: 4px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            color: #ff6600;
            font-weight: bold;
            font-size: 10px;
            margin-bottom: 4px;
        }
        .header {
            text-align: center;
            margin-bottom: 8mm;
            border-bottom: 2px solid #000;
            padding-bottom: 4mm;
        }
        .certificate-title {
            font-size: 20px;
            font-weight: bold;
            color: #0066cc;
            margin: 4px 0 2px 0;
            letter-spacing: 1px;
        }
        .certificate-title-ar {
            font-size: 14px;
            color: #0066cc;
            margin: 2px 0 4px 0;
            direction: rtl;
            font-weight: bold;
        }
        .detail-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin: 4px 0;
            padding: 3px 0;
            border-bottom: 1px solid #eee;
            min-height: 16px;
        }
        .detail-label {
            font-weight: bold;
            color: #333;
            display: flex;
            align-items: center;
            font-size: 12px;
            flex: 1;
        }
        .detail-label-ar {
            font-size: 10px;
            color: #666;
            margin-right: 6px;
            direction: rtl;
        }
        .detail-value {
            font-weight: bold;
            color: #000;
            text-align: right;
            font-size: 12px;
            flex: 0 0 auto;
            min-width: 100px;
        }
        .returns-section {
            margin: 8mm 0;
            border: 1px solid #ddd;
            border-radius: 4px;
            overflow: hidden;
            width: 100%;
            box-sizing: border-box;
        }
        .returns-header {
            background: #f8f9fa;
            padding: 4px 8px;
            border-bottom: 1px solid #ddd;
            font-weight: bold;
            color: #0066cc;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 12px;
        }
        .returns-header-left {
            display: flex;
            flex-direction: column;
        }
        .returns-header-right {
            display: flex;
            align-items: center;
            gap: 0;
            font-size: 10px;
            font-weight: bold;
            width: 320px;
        }
        .header-column {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 2px;
            text-align: center;
        }
        .header-column:nth-child(1) { width: 60px; } /* Status */
        .header-column:nth-child(2) { width: 60px; } /* Amount */
        .header-column:nth-child(3) { width: 60px; } /* Doc Type */
        .header-column:nth-child(4) { width: 60px; } /* Doc # */
        .header-column:nth-child(5) { width: 80px; } /* Vendor # */
        .header-column-ar {
            font-size: 8px;
            color: #666;
            direction: rtl;
        }
        .returns-header-ar {
            font-size: 10px;
            color: #666;
            direction: rtl;
            margin-top: 2px;
        }
        .returns-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 4px 8px;
            border-bottom: 1px solid #eee;
            font-size: 11px;
            min-height: 18px;
        }
        .returns-item:last-child {
            border-bottom: none;
        }
        .returns-category {
            display: flex;
            align-items: center;
            gap: 8px;
            flex: 1;
        }
        .returns-category-en {
            font-weight: 500;
            color: #333;
            font-size: 11px;
        }
        .returns-category-ar {
            font-size: 9px;
            color: #666;
            direction: rtl;
        }
        .returns-status {
            display: flex;
            align-items: center;
            gap: 0;
            flex: 0 0 auto;
            width: 320px;
            font-size: 10px;
        }
        .returns-status > span:nth-child(1) { width: 60px; text-align: center; } /* Status badge */
        .returns-status > span:nth-child(2) { width: 60px; text-align: center; } /* Amount */
        .returns-status > span:nth-child(3) { width: 60px; text-align: center; } /* Doc Type */
        .returns-status > span:nth-child(4) { width: 60px; text-align: center; } /* Doc # */
        .returns-status > span:nth-child(5) { width: 80px; text-align: center; } /* Vendor # */
        .status-badge {
            color: white;
            padding: 1px 2px;
            border-radius: 2px;
            font-size: 8px;
            font-weight: bold;
            min-width: 50px;
            text-align: center;
            display: inline-block;
        }
        .status-badge.yes {
            background: #28a745;
        }
        .status-badge.no {
            background: #dc3545;
        }
        .amount {
            font-weight: bold;
            text-align: center;
            font-size: 10px;
        }
        .doc-type {
            font-weight: 500;
            text-align: center;
            font-size: 9px;
            color: #333;
        }
        .doc-number {
            font-weight: 500;
            text-align: center;
            font-size: 9px;
            color: #333;
        }
        .vendor-doc {
            font-weight: 500;
            text-align: center;
            font-size: 9px;
            color: #333;
        }
        .total-row {
            background: #f8f9fa;
            font-weight: bold;
            border-top: 2px solid #0066cc;
            font-size: 12px;
        }
        .final-amount {
            background: #e8f4f8;
            font-size: 13px;
            font-weight: bold;
            color: #0066cc;
        }
        .personnel-section {
            margin: 6mm 0;
        }
        .signatures-section {
            margin: 15mm 0 4mm 0;
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 40px;
        }
        .signature-box {
            text-align: center;
        }
        .signature-title {
            font-weight: bold;
            margin-bottom: 5px;
            color: #333;
            font-size: 12px;
        }
        .signature-title-ar {
            font-size: 10px;
            color: #666;
            direction: rtl;
            margin-bottom: 10px;
        }
        .signature-line {
            border-top: 1px solid #333;
            margin-top: 35px;
            padding-top: 5px;
            font-style: italic;
            color: #666;
            font-size: 10px;
            height: 40px;
            display: flex;
            align-items: end;
            justify-content: center;
        }
        .footer-text {
            text-align: center;
            margin: 6mm 0 4mm 0;
            font-style: italic;
            color: #666;
            font-size: 10px;
        }
        .footer-text-ar {
            direction: rtl;
            font-size: 8px;
            margin-top: 2px;
        }
        .date-footer {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 4mm;
            font-weight: bold;
            color: #0066cc;
            font-size: 11px;
        }
        .date-ar {
            direction: rtl;
        }
        
        @media print {
            body {
                margin: 0;
                padding: 0;
                font-size: 10pt;
                line-height: 1.1;
            }
            .certificate-container {
                width: 100%;
                max-width: none;
                margin: 0;
                padding: 10mm;
                box-sizing: border-box;
                page-break-inside: avoid;
            }
            .logo {
                width: 40px;
                height: 30px;
                font-size: 8pt;
            }
            .certificate-title {
                font-size: 16pt;
            }
            .certificate-title-ar {
                font-size: 12pt;
            }
            .detail-row, .returns-item {
                page-break-inside: avoid;
                margin: 2px 0;
                padding: 2px 0;
            }
            .returns-section {
                margin: 4mm 0;
            }
            .signatures-section {
                margin: 6mm 0 2mm 0;
                gap: 25px;
            }
            .signature-line {
                margin-top: 25px;
                height: 30px;
            }
            .footer-text {
                margin: 3mm 0 2mm 0;
            }
            .date-footer {
                margin-top: 2mm;
            }
            .personnel-section {
                margin: 3mm 0;
            }
            
            /* Hide browser print elements */
            @page {
                margin: 10mm;
            }
            
            /* Ensure no browser artifacts */
            html, body {
                height: auto !important;
                overflow: visible !important;
            }
        }
        @media print {
            body { 
                background: white !important; 
                -webkit-print-color-adjust: exact; 
            }
        }
    </style>
</head>
<body>
    <div class="certificate-container">
        <!-- Logo -->
        <div class="logo-container">
            <img src="/icons/logo.png" alt="Company Logo" class="logo" style="width: 80px; height: 60px; object-fit: contain; border: 2px solid #ff6600; border-radius: 8px; padding: 5px;" />
        </div>
        
        <!-- Header -->
        <div class="header">
            <div class="certificate-title">CLEARANCE CERTIFICATION</div>
            <div class="certificate-title-ar">شهادة تخليص البضائع</div>
        </div>
        
        <!-- Vendor Name -->
        <div class="detail-row">
            <div class="detail-label">
                Vendor Name:
                <div class="detail-label-ar">اسم المورد:</div>
            </div>
            <div class="detail-value">${certificateData.vendor_name}</div>
        </div>
        
        <!-- Bill Details -->
        <div class="detail-row">
            <div class="detail-label">
                Bill Number:
                <div class="detail-label-ar">رقم الفاتورة:</div>
            </div>
            <div class="detail-value">${certificateData.bill_number}</div>
        </div>
        
        <div class="detail-row">
            <div class="detail-label">
                Bill Date:
                <div class="detail-label-ar">تاريخ الفاتورة:</div>
            </div>
            <div class="detail-value">${certificateData.bill_date}</div>
        </div>
        
        <div class="detail-row">
            <div class="detail-label">
                Branch:
                <div class="detail-label-ar">الفرع:</div>
            </div>
            <div class="detail-value">${certificateData.branch_name}</div>
        </div>
        
        <div class="detail-row">
            <div class="detail-label">
                Bill Amount:
                <div class="detail-label-ar">مبلغ الفاتورة:</div>
            </div>
            <div class="detail-value">${certificateData.bill_amount}.00</div>
        </div>
        
        <div class="detail-row">
            <div class="detail-label">
                Payment Method:
                <div class="detail-label-ar">طريقة الدفع:</div>
            </div>
            <div class="detail-value">${certificateData.payment_method}</div>
        </div>
        
        <!-- Returns Summary -->
        <div class="returns-section">
            <div class="returns-header">
                <div class="returns-header-left">
                    <span>Returns Summary: <span class="returns-header-ar">ملخص المرتجعات</span></span>
                </div>
                <div class="returns-header-right">
                    <div class="header-column">
                        <span>Status</span>
                        <span class="header-column-ar">الحالة</span>
                    </div>
                    <div class="header-column">
                        <span>Amount</span>
                        <span class="header-column-ar">المبلغ</span>
                    </div>
                    <div class="header-column">
                        <span>Doc Type</span>
                        <span class="header-column-ar">نوع الوثيقة</span>
                    </div>
                    <div class="header-column">
                        <span>Doc #</span>
                        <span class="header-column-ar">رقم الوثيقة</span>
                    </div>
                    <div class="header-column">
                        <span>Vendor #</span>
                        <span class="header-column-ar">رقم المورد</span>
                    </div>
                </div>
            </div>
            
            <div class="returns-item">
                <div class="returns-category">
                    <span class="returns-category-en">Expired Returns</span>
                    <span class="returns-category-ar">مرتجعات منتهية الصلاحية</span>
                </div>
                <div class="returns-status">
                    <span class="status-badge ${certificateData.expired_return_amount > 0 ? 'yes' : 'no'}">${certificateData.expired_return_amount > 0 ? 'Yes / نعم' : 'No / لا'}</span>
                    <span class="amount">${certificateData.expired_return_amount.toFixed(2)}</span>
                    <span class="doc-type">${certificateData.expired_erp_document_type}</span>
                    <span class="doc-number">${certificateData.expired_erp_document_number}</span>
                    <span class="vendor-doc">${certificateData.expired_vendor_document_number}</span>
                </div>
            </div>
            
            <div class="returns-item">
                <div class="returns-category">
                    <span class="returns-category-en">Near Expiry Returns</span>
                    <span class="returns-category-ar">مرتجعات قريبة الانتهاء</span>
                </div>
                <div class="returns-status">
                    <span class="status-badge ${certificateData.near_expiry_return_amount > 0 ? 'yes' : 'no'}">${certificateData.near_expiry_return_amount > 0 ? 'Yes / نعم' : 'No / لا'}</span>
                    <span class="amount">${certificateData.near_expiry_return_amount.toFixed(2)}</span>
                    <span class="doc-type">${certificateData.near_expiry_erp_document_type}</span>
                    <span class="doc-number">${certificateData.near_expiry_erp_document_number}</span>
                    <span class="vendor-doc">${certificateData.near_expiry_vendor_document_number}</span>
                </div>
            </div>
            
            <div class="returns-item">
                <div class="returns-category">
                    <span class="returns-category-en">Over Stock Returns</span>
                    <span class="returns-category-ar">مرتجعات فائض المخزون</span>
                </div>
                <div class="returns-status">
                    <span class="status-badge ${certificateData.over_stock_return_amount > 0 ? 'yes' : 'no'}">${certificateData.over_stock_return_amount > 0 ? 'Yes / نعم' : 'No / لا'}</span>
                    <span class="amount">${certificateData.over_stock_return_amount.toFixed(2)}</span>
                    <span class="doc-type">${certificateData.over_stock_erp_document_type}</span>
                    <span class="doc-number">${certificateData.over_stock_erp_document_number}</span>
                    <span class="vendor-doc">${certificateData.over_stock_vendor_document_number}</span>
                </div>
            </div>
            
            <div class="returns-item">
                <div class="returns-category">
                    <span class="returns-category-en">Damage Returns</span>
                    <span class="returns-category-ar">مرتجعات تالفة</span>
                </div>
                <div class="returns-status">
                    <span class="status-badge ${certificateData.damage_return_amount > 0 ? 'yes' : 'no'}">${certificateData.damage_return_amount > 0 ? 'Yes / نعم' : 'No / لا'}</span>
                    <span class="amount">${certificateData.damage_return_amount.toFixed(2)}</span>
                    <span class="doc-type">${certificateData.damage_erp_document_type}</span>
                    <span class="doc-number">${certificateData.damage_erp_document_number}</span>
                    <span class="vendor-doc">${certificateData.damage_vendor_document_number}</span>
                </div>
            </div>
            
            <div class="returns-item total-row">
                <div class="returns-category">
                    <span class="returns-category-en">Total Returns</span>
                    <span class="returns-category-ar">إجمالي المرتجعات</span>
                </div>
                <div class="returns-status">
                    <span class="status-badge" style="visibility: hidden;"></span>
                    <span class="amount">${certificateData.total_return_amount.toFixed(2)}</span>
                    <span class="doc-type">-</span>
                    <span class="doc-number">-</span>
                    <span class="vendor-doc">-</span>
                </div>
            </div>
        </div>
        
        <!-- Final Amount -->
        <div class="detail-row final-amount">
            <div class="detail-label">
                Final Amount:
                <div class="detail-label-ar">المبلغ النهائي:</div>
            </div>
            <div class="detail-value">${certificateData.final_bill_amount.toFixed(2)}</div>
        </div>
        
        <!-- Personnel Information -->
        <div class="personnel-section">
            <div class="detail-row">
                <div class="detail-label">
                    Salesman Name:
                    <div class="detail-label-ar">اسم البائع:</div>
                </div>
                <div class="detail-value">${certificateData.salesman_name}</div>
            </div>
            
            <div class="detail-row">
                <div class="detail-label">
                    Salesman Contact:
                    <div class="detail-label-ar">رقم البائع:</div>
                </div>
                <div class="detail-value">${certificateData.salesman_contact}</div>
            </div>
            
            <div class="detail-row">
                <div class="detail-label">
                    Logged Employee:
                    <div class="detail-label-ar">الموظف المسجل:</div>
                </div>
                <div class="detail-value">${certificateData.generated_by}</div>
            </div>
        </div>
        
        <!-- Signatures -->
        <div class="signatures-section">
            <div class="signature-box">
                <div class="signature-title">Salesman Signature</div>
                <div class="signature-title-ar">توقيع البائع</div>
                <div class="signature-line">${certificateData.salesman_name}</div>
            </div>
            <div class="signature-box">
                <div class="signature-title">Receiver Signature</div>
                <div class="signature-title-ar">توقيع المستلم</div>
                <div class="signature-line">${certificateData.generated_by}</div>
            </div>
        </div>
        
        <!-- Footer -->
        <div class="footer-text">
            This certification confirms the receipt of goods as per the details mentioned above.
            <div class="footer-text-ar">تؤكد هذه الشهادة استلام البضائع وفق التفاصيل المذكورة أعلاه.</div>
        </div>
        
        <div class="date-footer">
            <span>Date: ${certificateData.current_date}</span>
            <span class="date-ar">التاريخ: ${new Date().toLocaleDateString('ar-EG')}</span>
        </div>
    </div>
</body>
</html>`;
      
      // Store the HTML for display and potential saving
      certificateHtml = certificateHTML;
      certificateGenerated = true;
      
      // Create data URL for preview
      clearanceCertificateUrl = 'data:text/html;base64,' + btoa(unescape(encodeURIComponent(certificateHTML)));
      
      console.log('Professional clearance certificate template generated successfully');
      return true;
      
    } catch (error) {
      console.error('Error generating clearance certificate:', error);
      generationError = 'Failed to generate clearance certificate: ' + error.message;
      return false;
    } finally {
      isGenerating = false;
    }
  }

  // Save certificate as image to storage
  async function saveCertificateAsImage() {
    try {
      isUploading = true;
      uploadProgress = 0;
      generationError = '';

      // Create an iframe to render the certificate HTML
      const iframe = document.createElement('iframe');
      iframe.style.position = 'fixed';
      iframe.style.left = '-9999px';
      iframe.style.width = '800px';
      iframe.style.height = '1200px';
      document.body.appendChild(iframe);

      // Write the HTML to the iframe
      iframe.contentDocument.open();
      iframe.contentDocument.write(certificateHtml);
      iframe.contentDocument.close();

      // Wait for content to load
      await new Promise(resolve => {
        iframe.onload = resolve;
        setTimeout(resolve, 1000); // fallback timeout
      });

      uploadProgress = 30;

      // Create canvas from iframe content using html2canvas
      const html2canvas = (await import('html2canvas')).default;
      
      // Wait a bit more for fonts and styles to load
      await new Promise(resolve => setTimeout(resolve, 500));
      
      const canvas = await html2canvas(iframe.contentDocument.body, {
        width: 800,
        height: 1200,
        scale: 2, // Higher quality
        useCORS: true,
        allowTaint: false,
        backgroundColor: '#ffffff'
      });

      uploadProgress = 60;

      // Convert canvas to blob
      const blob = await new Promise(resolve => {
        canvas.toBlob(resolve, 'image/png', 0.9);
      });

      uploadProgress = 80;

      // Upload to Supabase storage
      const fileName = `clearance-certificate-${receivingRecord.id}-${Date.now()}.png`;
      
      // Upload to the existing clearance-certificates bucket
      const { data, error } = await supabase.storage
        .from('clearance-certificates')
        .upload(fileName, blob, {
          contentType: 'image/png',
          upsert: false
        });

      if (error) {
        throw new Error('Failed to upload certificate image: ' + error.message);
      }

      // Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('clearance-certificates')
        .getPublicUrl(fileName);

      certificateImageUrl = publicUrl;
      certificateSaved = true;
      uploadProgress = 100;

      // Update receiving record with certificate information
      const { error: updateError } = await supabase
        .from('receiving_records')
        .update({
          certificate_url: publicUrl,
          certificate_generated_at: new Date().toISOString(),
          certificate_file_name: fileName
        })
        .eq('id', receivingRecord.id);

      if (updateError) {
        console.error('Error updating receiving record:', updateError);
        // Don't fail the whole operation, just log the error
      } else {
        console.log('Receiving record updated with certificate information');
      }

      // Clean up
      document.body.removeChild(iframe);

      console.log('Certificate saved as image successfully:', publicUrl);
      return true;

    } catch (error) {
      console.error('Error saving certificate as image:', error);
      generationError = 'Failed to save certificate: ' + error.message;
      return false;
    } finally {
      isUploading = false;
    }
  }

  // Print certificate
  function printCertificate() {
    // Create a new window with proper title to avoid "about:blank"
    const printWindow = window.open('', '_blank', 'width=800,height=600');
    
    // Write the certificate HTML with proper page setup
    const printHTML = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Clearance Certificate</title>
        <meta charset="utf-8">
        <style>
          @media print {
            @page {
              size: A4;
              margin: 10mm;
            }
            html, body {
              margin: 0;
              padding: 0;
              height: auto !important;
              overflow: visible !important;
            }
          }
        </style>
      </head>
      <body>
        ${certificateHtml.replace('<!DOCTYPE html>', '').replace('<html>', '').replace('</html>', '').replace('<body>', '').replace('</body>', '')}
      </body>
      </html>
    `;
    
    printWindow.document.write(printHTML);
    printWindow.document.close();
    printWindow.focus();
    
    // Wait a moment for content to load, then print
    setTimeout(() => {
      printWindow.print();
      // Close the window after printing
      setTimeout(() => {
        printWindow.close();
      }, 1000);
    }, 500);
  }

  // Create tasks for selected users with certificate attachment
  async function createTasksWithCertificate() {
    if (!receivingRecord || !certificateImageUrl) {
      generationError = 'Certificate must be saved before creating tasks';
      return;
    }
    
    try {
      isGenerating = true;
      generationError = '';
      generationSuccess = '';
      
      // Get current user info
      const user = $currentUser;
      if (!user) {
        generationError = 'User not authenticated';
        return;
      }
      
      // Call the API to generate tasks
      const response = await fetch('/api/receiving-tasks', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          receiving_record_id: receivingRecord.id,
          clearance_certificate_url: certificateImageUrl, // Use the saved image URL
          generated_by_user_id: user.id,
          generated_by_name: user.username || user.displayName,
          generated_by_role: user.roleType
        })
      });
      
      const result = await response.json();
      
      if (!result.success) {
        throw new Error(result.error);
      }
      
      // Store results
      tasksSummary = result.data;
      tasksGenerated = true;
      generationSuccess = result.message;
      
      // Load the generated tasks
      await loadGeneratedTasks();
      
      console.log('Clearance certificate tasks generated successfully:', result);
      
    } catch (error) {
      console.error('Error generating clearance certificate tasks:', error);
      generationError = error.message;
    } finally {
      isGenerating = false;
    }
  }
  
  // Load generated tasks for the receiving record
  async function loadGeneratedTasks() {
    if (!receivingRecord?.id) return;
    
    try {
      const response = await fetch(`/api/receiving-tasks?receiving_record_id=${receivingRecord.id}`);
      const result = await response.json();
      
      if (result.success) {
        generatedTasks = result.tasks || [];
      }
      
    } catch (error) {
      console.error('Error loading generated tasks:', error);
    }
  }
  
  // Get task status badge color
  function getTaskStatusColor(status) {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'in_progress': return 'bg-blue-100 text-blue-800';
      case 'assigned': return 'bg-yellow-100 text-yellow-800';
      case 'overdue': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }
  
  // Get role type display name
  function getRoleDisplayName(roleType) {
    switch (roleType) {
      case 'branch_manager': return 'Branch Manager';
      case 'purchase_manager': return 'Purchase Manager';
      case 'inventory_manager': return 'Inventory Manager';
      case 'night_supervisor': return 'Night Supervisor';
      case 'warehouse_handler': return 'Warehouse Handler';
      case 'shelf_stocker': return 'Shelf Stocker';
      case 'accountant': return 'Accountant';
      default: return roleType;
    }
  }
  
  // Close the component
  function close() {
    show = false;
    dispatch('close');
  }
  
  // Check if tasks have already been generated when component mounts
  onMount(() => {
    if (show && receivingRecord && receivingRecord.id) {
      // Only load tasks if they might already exist (check silently)
      checkIfTasksExist();
    }
  });
  
  // Function to silently check if tasks exist without causing errors
  async function checkIfTasksExist() {
    if (!receivingRecord?.id) return;
    
    try {
      const response = await fetch(`/api/receiving-tasks?receiving_record_id=${receivingRecord.id}`);
      if (response.ok) {
        const result = await response.json();
        if (result.success && result.tasks && result.tasks.length > 0) {
          generatedTasks = result.tasks;
          tasksGenerated = true;
        }
      }
      // If no tasks exist or there's an error, just ignore it - tasks haven't been generated yet
    } catch (error) {
      // Silently ignore errors - tasks simply haven't been generated yet
    }
  }
</script>

{#if show}
  <!-- Modal backdrop -->
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-hidden">
      <!-- Header -->
      <div class="bg-gradient-to-r from-blue-600 to-blue-700 text-white px-6 py-4">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-xl font-semibold">Clearance Certificate Manager</h2>
            <p class="text-blue-100 text-sm">Generate tasks for receiving process</p>
          </div>
          <button
            on:click={close}
            class="text-white hover:text-gray-200 text-2xl font-bold"
          >
            ×
          </button>
        </div>
      </div>
      
      <!-- Content -->
      <div class="p-6 overflow-y-auto max-h-[calc(90vh-120px)]">
        {#if receivingRecord}
          <!-- Receiving Record Info -->
          <div class="bg-gray-50 rounded-lg p-4 mb-6">
            <h3 class="font-medium text-gray-900 mb-2">Receiving Record Details</h3>
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span class="text-gray-600">Record ID:</span>
                <span class="font-mono ml-2">{receivingRecord.id}</span>
              </div>
              <div>
                <span class="text-gray-600">Bill Date:</span>
                <span class="ml-2">{receivingRecord.bill_date}</span>
              </div>
              <div>
                <span class="text-gray-600">Bill Amount:</span>
                <span class="ml-2">${receivingRecord.bill_amount}</span>
              </div>
              <div>
                <span class="text-gray-600">Bill Number:</span>
                <span class="ml-2">{receivingRecord.bill_number || 'N/A'}</span>
              </div>
            </div>
          </div>
          
          {#if !certificateGenerated}
            <!-- Step 1: Generate Certificate Template -->
            <div class="mb-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Generate Clearance Certificate</h3>
              
              <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 mb-4">
                <div class="text-center">
                  <svg class="mx-auto h-12 w-12 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <div class="mt-4">
                    <span class="mt-2 block text-sm font-medium text-gray-900">
                      Professional Certificate Template
                    </span>
                    <span class="mt-1 block text-sm text-gray-600">
                      Generate a professional clearance certificate with receiving details
                    </span>
                  </div>
                </div>
              </div>
              
              <button
                on:click={generateClearanceCertificateDocument}
                disabled={isGenerating}
                class="w-full bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
              >
                {#if isGenerating}
                  <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Generating Certificate...
                {:else}
                  📄 Generate Clearance Certificate
                {/if}
              </button>
            </div>
          {:else if !certificateSaved}
            <!-- Step 2: Show Certificate Template with Save and Print buttons -->
            <div class="mb-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Clearance Certificate Generated</h3>
              
              <!-- Certificate Preview -->
              <div class="border border-gray-300 rounded-lg mb-4">
                <div class="bg-gray-50 px-4 py-2 border-b border-gray-300 flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-700">Certificate Preview</span>
                  <a 
                    href={clearanceCertificateUrl} 
                    target="_blank"
                    class="text-blue-600 hover:text-blue-800 text-sm"
                  >
                    Open in New Tab
                  </a>
                </div>
                <iframe 
                  src={clearanceCertificateUrl} 
                  class="w-full h-96 border-0"
                  title="Certificate Preview"
                ></iframe>
              </div>
              
              <!-- Action Buttons -->
              <div class="flex space-x-3">
                <button
                  on:click={saveCertificateAsImage}
                  disabled={isUploading}
                  class="flex-1 bg-green-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                >
                  {#if isUploading}
                    <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Saving...
                  {:else}
                    💾 Save
                  {/if}
                </button>
                
                <button
                  on:click={printCertificate}
                  class="flex-1 bg-gray-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-gray-700 flex items-center justify-center"
                >
                  🖨️ Print
                </button>
              </div>
              
              {#if isUploading}
                <div class="mt-4">
                  <div class="bg-gray-200 rounded-full h-2">
                    <div class="bg-green-600 h-2 rounded-full transition-all duration-300" style="width: {uploadProgress}%"></div>
                  </div>
                  <p class="text-sm text-gray-600 mt-2 text-center">Saving certificate... {uploadProgress}%</p>
                </div>
              {/if}
            </div>
          {:else if !tasksGenerated}
            <!-- Step 3: Certificate Saved, Show Assign Tasks button -->
            <div class="mb-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Certificate Saved Successfully</h3>
              
              <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                <div class="flex items-center">
                  <svg class="h-5 w-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                  <div>
                    <h4 class="text-sm font-medium text-green-800">Certificate Saved</h4>
                    <p class="text-sm text-green-700 mt-1">Certificate has been saved as an image and is ready to be attached to tasks.</p>
                  </div>
                </div>
              </div>

              <!-- Preview saved image -->
              <div class="border border-gray-300 rounded-lg mb-4">
                <div class="bg-gray-50 px-4 py-2 border-b border-gray-300 flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-700">Saved Certificate Image</span>
                  <a 
                    href={certificateImageUrl} 
                    target="_blank"
                    class="text-blue-600 hover:text-blue-800 text-sm"
                  >
                    View Image
                  </a>
                </div>
                <img 
                  src={certificateImageUrl} 
                  alt="Clearance Certificate" 
                  class="w-full h-64 object-contain bg-white"
                />
              </div>
              
              <button
                on:click={createTasksWithCertificate}
                disabled={isGenerating}
                class="w-full bg-orange-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
              >
                {#if isGenerating}
                  <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Creating Tasks...
                {:else}
                  🚀 Assign Tasks
                {/if}
              </button>
            </div>
          {:else}
            <!-- Step 4: Tasks Generated Successfully -->
            <!-- Tasks Generated Successfully -->
            <div class="mb-6">
              <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                <div class="flex items-center">
                  <svg class="h-5 w-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                  <div>
                    <h3 class="text-sm font-medium text-green-800">Tasks Generated Successfully!</h3>
                    <p class="text-sm text-green-700 mt-1">{generationSuccess}</p>
                  </div>
                </div>
              </div>
              
              {#if tasksSummary}
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                  <h4 class="font-medium text-blue-900 mb-2">Generation Summary</h4>
                  <div class="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <span class="text-blue-700">Tasks Created:</span>
                      <span class="font-semibold ml-2">{tasksSummary.tasks_created}</span>
                    </div>
                    <div>
                      <span class="text-blue-700">Notifications Sent:</span>
                      <span class="font-semibold ml-2">{tasksSummary.notifications_sent}</span>
                    </div>
                  </div>
                </div>
              {/if}
            </div>
          {/if}
          
          <!-- Error Messages -->
          {#if generationError}
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
              <div class="flex items-center">
                <svg class="h-5 w-5 text-red-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>
                <div>
                  <h3 class="text-sm font-medium text-red-800">Error</h3>
                  <p class="text-sm text-red-700 mt-1">{generationError}</p>
                </div>
              </div>
            </div>
          {/if}
          
          <!-- Generated Tasks List -->
          {#if generatedTasks.length > 0}
            <div class="mb-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Generated Tasks</h3>
              <div class="space-y-4">
                {#each generatedTasks as task}
                  <div class="border border-gray-200 rounded-lg p-4">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <div class="flex items-center space-x-2 mb-2">
                          <span class="px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            {getRoleDisplayName(task.role_type)}
                          </span>
                          <span class="px-2 py-1 rounded-full text-xs font-medium {getTaskStatusColor(task.assignment_status)}">
                            {task.assignment_status}
                          </span>
                          {#if task.is_overdue}
                            <span class="px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
                              Overdue
                            </span>
                          {/if}
                        </div>
                        
                        <h4 class="font-medium text-gray-900 mb-1">{task.task_title}</h4>
                        <p class="text-sm text-gray-600 mb-2">{task.task_description}</p>
                        
                        <div class="text-xs text-gray-500 space-y-1">
                          {#if task.deadline_datetime}
                            <div>📅 Deadline: {new Date(task.deadline_datetime).toLocaleString()}</div>
                          {/if}
                          {#if task.requires_erp_reference}
                            <div>📊 Requires ERP Reference</div>
                          {/if}
                          {#if task.requires_original_bill_upload}
                            <div>📎 Requires Original Bill Upload</div>
                          {/if}
                          {#if task.requires_reassignment}
                            <div>🔄 Can be Reassigned</div>
                          {/if}
                        </div>
                      </div>
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
          
        {:else}
          <div class="text-center py-8">
            <p class="text-gray-500">No receiving record provided</p>
          </div>
        {/if}
      </div>
      
      <!-- Footer -->
      <div class="bg-gray-50 px-6 py-4 flex justify-end space-x-3">
        <button
          on:click={close}
          class="px-4 py-2 text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
        >
          Close
        </button>
      </div>
    </div>
  </div>
{/if}