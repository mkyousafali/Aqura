package mobileinterface

import (
	"database/sql"
	"encoding/json"
	"time"
)

// DailySales represents a daily sales record from erp_daily_sales table
type DailySales struct {
	ID             string          `json:"id"`              // uuid
	BranchID       int64           `json:"branch_id"`       // bigint NOT NULL
	SaleDate       string          `json:"sale_date"`       // date NOT NULL (formatted as YYYY-MM-DD)
	TotalBills     sql.NullInt64   `json:"-"`               // integer nullable (custom marshal)
	GrossAmount    sql.NullFloat64 `json:"-"`               // numeric(18,2) nullable (custom marshal)
	TaxAmount      sql.NullFloat64 `json:"-"`               // numeric(18,2) nullable (custom marshal)
	DiscountAmount sql.NullFloat64 `json:"-"`               // numeric(18,2) nullable (custom marshal)
	TotalReturns   sql.NullInt64   `json:"-"`               // integer nullable (custom marshal)
	ReturnAmount   sql.NullFloat64 `json:"-"`               // numeric(18,2) nullable (custom marshal)
	ReturnTax      sql.NullFloat64 `json:"-"`               // numeric(18,2) nullable (custom marshal)
	NetBills       sql.NullInt64   `json:"-"`               // integer nullable (custom marshal)
	NetAmount      sql.NullFloat64 `json:"-"`               // numeric(18,2) nullable (custom marshal)
	NetTax         sql.NullFloat64 `json:"-"`               // numeric(18,2) nullable (custom marshal)
	LastSyncAt     sql.NullTime    `json:"-"`               // timestamp with time zone nullable (custom marshal)
	CreatedAt      time.Time       `json:"created_at"`      // timestamp with time zone
	UpdatedAt      time.Time       `json:"updated_at"`      // timestamp with time zone
}

// MarshalJSON custom marshaler to handle nullable fields properly
func (d DailySales) MarshalJSON() ([]byte, error) {
	type Alias DailySales
	return json.Marshal(&struct {
		*Alias
		TotalBills     *int64   `json:"total_bills"`
		GrossAmount    *float64 `json:"gross_amount"`
		TaxAmount      *float64 `json:"tax_amount"`
		DiscountAmount *float64 `json:"discount_amount"`
		TotalReturns   *int64   `json:"total_returns"`
		ReturnAmount   *float64 `json:"return_amount"`
		ReturnTax      *float64 `json:"return_tax"`
		NetBills       *int64   `json:"net_bills"`
		NetAmount      *float64 `json:"net_amount"`
		NetTax         *float64 `json:"net_tax"`
		LastSyncAt     *string  `json:"last_sync_at"`
	}{
		Alias:          (*Alias)(&d),
		TotalBills:     nullInt64ToPtr(d.TotalBills),
		GrossAmount:    nullFloat64ToPtr(d.GrossAmount),
		TaxAmount:      nullFloat64ToPtr(d.TaxAmount),
		DiscountAmount: nullFloat64ToPtr(d.DiscountAmount),
		TotalReturns:   nullInt64ToPtr(d.TotalReturns),
		ReturnAmount:   nullFloat64ToPtr(d.ReturnAmount),
		ReturnTax:      nullFloat64ToPtr(d.ReturnTax),
		NetBills:       nullInt64ToPtr(d.NetBills),
		NetAmount:      nullFloat64ToPtr(d.NetAmount),
		NetTax:         nullFloat64ToPtr(d.NetTax),
		LastSyncAt:     nullTimeToPtr(d.LastSyncAt),
	})
}

// Helper functions to convert sql.Null* to pointers
func nullInt64ToPtr(n sql.NullInt64) *int64 {
	if n.Valid {
		return &n.Int64
	}
	return nil
}

func nullFloat64ToPtr(n sql.NullFloat64) *float64 {
	if n.Valid {
		return &n.Float64
	}
	return nil
}

func nullTimeToPtr(n sql.NullTime) *string {
	if n.Valid {
		str := n.Time.Format(time.RFC3339)
		return &str
	}
	return nil
}

// DailySalesResponse represents API response with sales data
type DailySalesResponse struct {
	Records []DailySales `json:"records"`
	Count   int          `json:"count"`
}
