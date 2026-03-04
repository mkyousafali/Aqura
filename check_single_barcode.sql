SELECT 
    ISNULL(pu.BarCode, pb.MannualBarcode) AS Barcode,
    pb.ProductBatchID,
    pb.StdPurchasePrice,
    pb.LastPurchaseCost,
    pb.LandingCost,
    pb.AvgPurchaseCost,
    ISNULL(pu.MultiFactor, 1) AS MultiFactor,
    COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) * ISNULL(pu.MultiFactor, 1) AS CalculatedCost
FROM ProductBatches pb
LEFT JOIN ProductUnits pu ON pb.ProductBatchID = pu.ProductBatchID
WHERE pb.MannualBarcode = '6281004294228' OR CAST(pb.AutoBarcode AS NVARCHAR(100)) = '6281004294228'
   OR pb.Unit2Barcode = '6281004294228' OR pb.Unit3Barcode = '6281004294228'
   OR EXISTS (SELECT 1 FROM ProductUnits pu2 WHERE pu2.BarCode = '6281004294228' AND pu2.ProductBatchID = pb.ProductBatchID)
   OR EXISTS (SELECT 1 FROM ProductBarcodes pbc WHERE pbc.Barcode = '6281004294228' AND pbc.ProductBatchID = pb.ProductBatchID)
