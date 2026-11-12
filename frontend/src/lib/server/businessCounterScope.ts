import type { BusinessCounterProfile } from '$lib/types/businessCounter';

/** SQL scope for the existing p (Products) and g (ProductGroups) aliases. */
export function counterSalesScope(profile: BusinessCounterProfile, branchId: string | number): string {
		const group = profile.productGroup.replace(/'/g, "''");
		// Arda is Aqura branch 3; its ERP branch mapping is a separate value.
		const extraBarcode = profile.id === 'bakery' && Number(branchId) === 3 ? '400498' : null;
		const extraProductScope = extraBarcode === null ? '' : ` OR EXISTS (
			SELECT 1 FROM ProductBatches extraBatch
			WHERE extraBatch.ProductID = p.ProductID AND extraBatch.BranchID = p.BranchID
				AND (extraBatch.MannualBarcode = N'${extraBarcode}'
					OR CAST(extraBatch.AutoBarcode AS NVARCHAR(100)) = N'${extraBarcode}'
					OR extraBatch.Unit2Barcode = N'${extraBarcode}' OR extraBatch.Unit3Barcode = N'${extraBarcode}'
					OR EXISTS (SELECT 1 FROM ProductUnits extraUnit
						WHERE extraUnit.ProductBatchID = extraBatch.ProductBatchID AND extraUnit.BranchID = extraBatch.BranchID
							AND extraUnit.BarCode = N'${extraBarcode}')
					OR EXISTS (SELECT 1 FROM ProductBarcodes extraCode
						WHERE extraCode.ProductBatchID = extraBatch.ProductBatchID AND extraCode.Barcode = N'${extraBarcode}'))
		)`;
		return `(LTRIM(RTRIM(g.GroupName)) = N'${group}'${extraProductScope})`;
}
