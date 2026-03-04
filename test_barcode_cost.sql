-- Test query for barcode 6281004294228
SELECT 
    'ProductUnits BarCode' AS SourceType,
    pu.BarCode AS Barcode,
    pb.ProductBatchID,
    pb.StdPurchasePrice,
    pb.LastPurchaseCost,
    pb.LandingCost,
    pb.AvgPurchaseCost,
    pu.MultiFactor,
    COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) * pu.MultiFactor AS FinalCost
FROM ProductUnits pu
INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID
WHERE pu.BarCode = '6281004294228'

UNION ALL

SELECT 
    'MannualBarcode' AS SourceType,
    pb.MannualBarcode AS Barcode,
    pb.ProductBatchID,
    pb.StdPurchasePrice,
    pb.LastPurchaseCost,
    pb.LandingCost,
    pb.AvgPurchaseCost,
    ISNULL((SELECT TOP 1 MultiFactor FROM ProductUnits WHERE ProductBatchID = pb.ProductBatchID ORDER BY MultiFactor DESC), 1) AS MultiFactor,
    COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) * ISNULL((SELECT TOP 1 MultiFactor FROM ProductUnits WHERE ProductBatchID = pb.ProductBatchID ORDER BY MultiFactor DESC), 1) AS FinalCost
FROM ProductBatches pb
WHERE pb.MannualBarcode = '6281004294228'
