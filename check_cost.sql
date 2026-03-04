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
WHERE pb.MannualBarcode IN ('7622201746667', '69551810181835', '6281051410030', '8885050401136')
