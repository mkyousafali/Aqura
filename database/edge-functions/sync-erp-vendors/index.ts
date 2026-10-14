import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const jsonHeaders = { 'Content-Type': 'application/json' }
type ErpSupplier = {
  PartyCode?: unknown
  PartyName?: unknown
  TaxNumber?: unknown
}

type VendorRow = {
  erp_vendor_id: number
  branch_id: number
  vendor_name: string
  vat_number?: string
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

function normalizedName(value: unknown) {
  return String(value ?? '').normalize('NFKC').replace(/\s+/g, ' ').trim()
}

function normalizedVat(value: unknown) {
  const digits = String(value ?? '').replace(/\D/g, '')
  return digits.length === 15 && digits.startsWith('3') && digits.endsWith('3')
    ? digits
    : null
}

serve(async (req) => {
  if (req.method !== 'POST') return jsonResponse({ success: false, error: 'POST required' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ success: false, error: 'Function environment is incomplete' }, 500)
  }

  if (req.headers.get('authorization') !== `Bearer ${serviceRoleKey}`) {
    return jsonResponse({ success: false, error: 'Unauthorized' }, 401)
  }

  try {
    const body = await req.json().catch(() => ({}))
    const branchId = Number(body.branchId)
    const syncMode = body.syncMode === 'auto' ? 'auto' : 'manual'
    if (!Number.isSafeInteger(branchId) || branchId <= 0) {
      return jsonResponse({ success: false, error: 'A valid branchId is required' }, 400)
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey)
    const { data: connection, error: connectionError } = await supabase
      .from('erp_connections')
      .select('branch_id,erp_branch_id,tunnel_url,bridge_api_secret,vendor_sync_enabled,vendor_auto_sync_enabled')
      .eq('branch_id', branchId)
      .eq('is_active', true)
      .maybeSingle()

    if (connectionError) throw connectionError
    if (!connection?.tunnel_url || !connection?.bridge_api_secret || !connection?.erp_branch_id) {
      return jsonResponse({ success: false, error: 'No active ERP tunnel is configured' }, 404)
    }
    if (!connection.vendor_sync_enabled) {
      return jsonResponse({ success: false, error: 'Vendor synchronization is disabled for this branch' }, 403)
    }
    if (syncMode === 'auto' && !connection.vendor_auto_sync_enabled) {
      return jsonResponse({ success: false, error: 'Automatic vendor synchronization is disabled for this branch' }, 403)
    }

    const erpBranchId = Number(connection.erp_branch_id)
    if (!Number.isInteger(erpBranchId)) throw new Error('Invalid ERP branch mapping')

    // Parties is authoritative. Do not join AccLedgers: a PartyCode may match
    // multiple active ledgers, while Parties.LedgerID points to only one.
    const supplierSql = `
      SELECT p.PartyCode, p.PartyName, p.TaxNumber
      FROM Parties p
      WHERE p.BranchID = ${erpBranchId}
        AND p.PartyType = 'Supp'
        AND p.IsActive = 1
      ORDER BY p.PartyCode
    `

    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 45_000)
    let bridgeResponse: Response
    try {
      bridgeResponse = await fetch(`${String(connection.tunnel_url).replace(/\/+$/, '')}/query`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-secret': connection.bridge_api_secret,
        },
        body: JSON.stringify({ sql: supplierSql }),
        signal: controller.signal,
      })
    } finally {
      clearTimeout(timeout)
    }

    const bridgeResult = await bridgeResponse.json().catch(() => ({}))
    if (!bridgeResponse.ok || bridgeResult.success === false) {
      throw new Error(bridgeResult.error || `ERP bridge returned HTTP ${bridgeResponse.status}`)
    }

    const suppliers = (Array.isArray(bridgeResult.recordset) ? bridgeResult.recordset : []) as ErpSupplier[]
    const valid = new Map<number, VendorRow>()
    const skipped: Array<{ partyCode: string; reason: string }> = []
    let validVatCount = 0
    let invalidOrEmptyVatCount = 0

    for (const supplier of suppliers) {
      const rawCode = String(supplier.PartyCode ?? '').trim()
      const vendorName = normalizedName(supplier.PartyName)
      if (!/^\d+$/.test(rawCode)) {
        skipped.push({ partyCode: rawCode, reason: 'blank or non-numeric PartyCode' })
        continue
      }
      const vendorId = Number(rawCode)
      if (!Number.isSafeInteger(vendorId) || vendorId > 2_147_483_647) {
        skipped.push({ partyCode: rawCode, reason: 'PartyCode exceeds vendors.erp_vendor_id integer range' })
        continue
      }
      if (!vendorName) {
        skipped.push({ partyCode: rawCode, reason: 'blank PartyName' })
        continue
      }
      if (valid.has(vendorId)) {
        skipped.push({ partyCode: rawCode, reason: 'duplicate normalized PartyCode' })
        continue
      }

      const vatNumber = normalizedVat(supplier.TaxNumber)
      if (vatNumber) validVatCount += 1
      else invalidOrEmptyVatCount += 1

      valid.set(vendorId, {
        erp_vendor_id: vendorId,
        branch_id: branchId,
        vendor_name: vendorName,
        ...(vatNumber ? { vat_number: vatNumber } : {}),
      })
    }

    const { data: existingRows, error: existingError } = await supabase
      .from('vendors')
      .select('erp_vendor_id,vendor_name,vat_number')
      .eq('branch_id', branchId)
    if (existingError) throw existingError

    const existing = new Map(
      (existingRows || []).map((row) => [Number(row.erp_vendor_id), row]),
    )
    const newWithVat: VendorRow[] = []
    const newWithoutVat: VendorRow[] = []
    const updates: Array<{ vendorId: number; patch: Record<string, string> }> = []
    let inserted = 0
    let namesUpdated = 0
    let vatsUpdated = 0
    let unchanged = 0

    for (const row of valid.values()) {
      const current = existing.get(row.erp_vendor_id)
      const isNew = !current
      const nameChanged = isNew || normalizedName(current.vendor_name) !== row.vendor_name
      const vatChanged = Boolean(row.vat_number) && (isNew || String(current.vat_number ?? '') !== row.vat_number)

      if (isNew) {
        inserted += 1
        if (row.vat_number) newWithVat.push(row)
        else newWithoutVat.push(row)
        continue
      }

      if (nameChanged) namesUpdated += 1
      if (vatChanged) vatsUpdated += 1
      if (!nameChanged && !vatChanged) {
        unchanged += 1
        continue
      }

      const patch: Record<string, string> = {}
      if (nameChanged) patch.vendor_name = row.vendor_name
      if (vatChanged && row.vat_number) patch.vat_number = row.vat_number
      updates.push({ vendorId: row.erp_vendor_id, patch })
    }

    // Insert new rows separately. Existing rows are patched field by field so
    // blank/invalid ERP VAT data can never erase an Aqura-maintained VAT value.
    for (const rows of [newWithVat, newWithoutVat]) {
      if (!rows.length) continue
      const { error } = await supabase.from('vendors').insert(rows)
      if (error) throw error
    }

    for (let offset = 0; offset < updates.length; offset += 12) {
      const results = await Promise.all(
        updates.slice(offset, offset + 12).map(({ vendorId, patch }) =>
          supabase
            .from('vendors')
            .update(patch)
            .eq('branch_id', branchId)
            .eq('erp_vendor_id', vendorId)
        ),
      )
      const failed = results.find((result) => result.error)
      if (failed?.error) throw failed.error
    }

    const syncedAt = new Date().toISOString()
    if (syncMode === 'auto') {
      const { error: timestampError } = await supabase
        .from('erp_connections')
        .update({ vendor_last_auto_sync_at: syncedAt })
        .eq('branch_id', branchId)
        .eq('is_active', true)
      if (timestampError) throw timestampError
    }

    return jsonResponse({
      success: true,
      branchId,
      erpBranchId,
      syncMode,
      syncedAt,
      erpRows: suppliers.length,
      validSuppliers: valid.size,
      inserted,
      namesUpdated,
      vatsUpdated,
      unchanged,
      validVatCount,
      invalidOrEmptyVatCount,
      skippedCount: skipped.length,
      skipped,
    })
  } catch (error) {
    console.error('ERP vendor synchronization failed:', error)
    return jsonResponse({
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }, 500)
  }
})
