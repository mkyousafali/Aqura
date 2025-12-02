package desktopinterface

import (
	"database/sql"
	"time"

	"github.com/mkyousafali/Aqura/backend/models"
)

// Branch represents the branches table structure from Supabase
type Branch struct {
	ID                    int64          `json:"id" db:"id"`
	NameEn                string         `json:"name_en" db:"name_en"`
	NameAr                string         `json:"name_ar" db:"name_ar"`
	LocationEn            string         `json:"location_en" db:"location_en"`
	LocationAr            string         `json:"location_ar" db:"location_ar"`
	IsActive              *bool          `json:"is_active" db:"is_active"`
	IsMainBranch          *bool          `json:"is_main_branch" db:"is_main_branch"`
	CreatedAt             *time.Time     `json:"created_at" db:"created_at"`
	UpdatedAt             *time.Time     `json:"updated_at" db:"updated_at"`
	CreatedBy             sql.NullInt64     `json:"created_by,omitempty" db:"created_by"`
	UpdatedBy             sql.NullInt64     `json:"updated_by,omitempty" db:"updated_by"`
	VatNumber             models.NullString `json:"vat_number,omitempty" db:"vat_number"`
	DeliveryServiceEnabled bool             `json:"delivery_service_enabled" db:"delivery_service_enabled"`
	PickupServiceEnabled  bool              `json:"pickup_service_enabled" db:"pickup_service_enabled"`
	MinimumOrderAmount    *float64          `json:"minimum_order_amount" db:"minimum_order_amount"`
	Is24Hours             *bool             `json:"is_24_hours" db:"is_24_hours"`
	OperatingStartTime    sql.NullTime      `json:"operating_start_time,omitempty" db:"operating_start_time"`
	OperatingEndTime      sql.NullTime      `json:"operating_end_time,omitempty" db:"operating_end_time"`
	DeliveryMessageAr     models.NullString `json:"delivery_message_ar,omitempty" db:"delivery_message_ar"`
	DeliveryMessageEn     models.NullString `json:"delivery_message_en,omitempty" db:"delivery_message_en"`
	DeliveryIs24Hours     *bool             `json:"delivery_is_24_hours" db:"delivery_is_24_hours"`
	DeliveryStartTime     sql.NullTime   `json:"delivery_start_time,omitempty" db:"delivery_start_time"`
	DeliveryEndTime       sql.NullTime   `json:"delivery_end_time,omitempty" db:"delivery_end_time"`
	PickupIs24Hours       *bool          `json:"pickup_is_24_hours" db:"pickup_is_24_hours"`
	PickupStartTime       sql.NullTime   `json:"pickup_start_time,omitempty" db:"pickup_start_time"`
	PickupEndTime         sql.NullTime   `json:"pickup_end_time,omitempty" db:"pickup_end_time"`
}

// CreateBranchInput represents the input for creating a new branch
type CreateBranchInput struct {
	NameEn                string  `json:"name_en" binding:"required"`
	NameAr                string  `json:"name_ar" binding:"required"`
	LocationEn            string  `json:"location_en" binding:"required"`
	LocationAr            string  `json:"location_ar" binding:"required"`
	IsActive              *bool   `json:"is_active"`
	IsMainBranch          *bool   `json:"is_main_branch"`
	VatNumber             *string `json:"vat_number"`
	DeliveryServiceEnabled bool   `json:"delivery_service_enabled"`
	PickupServiceEnabled  bool    `json:"pickup_service_enabled"`
	MinimumOrderAmount    *float64 `json:"minimum_order_amount"`
	Is24Hours             *bool   `json:"is_24_hours"`
}

// UpdateBranchInput represents the input for updating a branch
type UpdateBranchInput struct {
	NameEn                *string  `json:"name_en"`
	NameAr                *string  `json:"name_ar"`
	LocationEn            *string  `json:"location_en"`
	LocationAr            *string  `json:"location_ar"`
	IsActive              *bool    `json:"is_active"`
	IsMainBranch          *bool    `json:"is_main_branch"`
	VatNumber             *string  `json:"vat_number"`
	DeliveryServiceEnabled *bool   `json:"delivery_service_enabled"`
	PickupServiceEnabled  *bool    `json:"pickup_service_enabled"`
	MinimumOrderAmount    *float64 `json:"minimum_order_amount"`
	Is24Hours             *bool    `json:"is_24_hours"`
}
