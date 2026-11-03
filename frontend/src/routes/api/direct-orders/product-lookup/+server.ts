import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';
import { requireDirectOrderAccess } from '$lib/server/directOrderAccess';

const headers = { 'Cache-Control': 'no-store' };

export const POST: RequestHandler = async ({ cookies, request, fetch }) => {
	const { db } = await requireDirectOrderAccess(cookies, request.headers.get('x-aqura-interface') === 'mobile' ? 'mobile' : 'desktop');

	const body = await request.json().catch(() => null);
	const branchId = Number(body?.branchId);
	const barcode = typeof body?.barcode === 'string' ? body.barcode.trim() : '';
	if (!Number.isSafeInteger(branchId) || branchId <= 0 || !barcode || barcode.length > 100 || /[\u0000-\u001f\u007f]/.test(barcode)) {
		return json({ success: false, error: 'Select a valid branch and enter a valid barcode.' }, { status: 400, headers });
	}

	try {
		const [branchResult, connectionResult] = await Promise.all([
			db.from('branches').select('id').eq('id', branchId).eq('is_active', true).maybeSingle(),
			db.from('erp_connections').select('tunnel_url, bridge_api_secret, erp_branch_id')
				.eq('branch_id', branchId).eq('is_active', true).maybeSingle()
		]);
		if (branchResult.error) throw branchResult.error;
		if (connectionResult.error) throw connectionResult.error;
		if (!branchResult.data) return json({ success: false, error: 'The selected branch is unavailable.' }, { status: 400, headers });
		const connection = connectionResult.data;
		const erpBranchId = Number(connection?.erp_branch_id);
		if (!connection?.tunnel_url || !connection.bridge_api_secret || !Number.isSafeInteger(erpBranchId) || erpBranchId <= 0) {
			return json({ success: false, error: 'The selected branch ERP connection is unavailable.' }, { status: 503, headers });
		}

		// Use the selected branch's SQL Server and its ERP branch mapping. Match
		// every barcode source used by the existing ERP product lookup flows.
		const escapedBarcode = barcode.replace(/'/g, "''");
		const sql = `SELECT TOP 1 p.ProductName AS product_name_en
			FROM ProductBatches pb
			INNER JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = pb.BranchID
			WHERE pb.BranchID = ${erpBranchId} AND (
				pb.MannualBarcode = N'${escapedBarcode}'
				OR CAST(pb.AutoBarcode AS NVARCHAR(100)) = N'${escapedBarcode}'
				OR pb.Unit2Barcode = N'${escapedBarcode}'
				OR pb.Unit3Barcode = N'${escapedBarcode}'
				OR EXISTS (SELECT 1 FROM ProductUnits pu
					WHERE pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID AND pu.BarCode = N'${escapedBarcode}')
				OR EXISTS (SELECT 1 FROM ProductBarcodes pbc
					WHERE pbc.ProductBatchID = pb.ProductBatchID AND pbc.Barcode = N'${escapedBarcode}')
			) ORDER BY pb.ProductBatchID DESC`;
		const response = await fetch(`${connection.tunnel_url.replace(/\/+$/, '')}/query`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', 'x-api-secret': connection.bridge_api_secret },
			body: JSON.stringify({ sql }),
			signal: AbortSignal.timeout(15000)
		});
		const result = await response.json().catch(() => null);
		if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) {
			return json({ success: false, error: 'Unable to look up the product in the selected branch ERP.' }, { status: 502, headers });
		}
		const name = result.recordset[0]?.product_name_en;
		const productNameEn = typeof name === 'string' ? name.trim() : '';
		return json({ success: true, found: !!productNameEn, productNameEn }, { headers });
	} catch (failure) {
		const timedOut = failure instanceof Error && ['AbortError', 'TimeoutError'].includes(failure.name);
		return json({ success: false, error: timedOut ? 'The branch ERP lookup timed out.' : 'Unable to look up the product.' }, {
			status: timedOut ? 504 : 500, headers
		});
	}
};
