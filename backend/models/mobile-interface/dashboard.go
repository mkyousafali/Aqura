package mobileinterface

import (
	"time"
)

// DashboardStats represents the mobile dashboard statistics
type DashboardStats struct {
	PendingTasks int `json:"pending_tasks"`
}

// PunchRecord represents a fingerprint punch transaction
type PunchRecord struct {
	Time     string `json:"time"`
	Date     string `json:"date"`
	Status   string `json:"status"`
	RawDate  string `json:"raw_date"`
	RawTime  string `json:"raw_time"`
}

// PunchesResponse represents the response for punch records
type PunchesResponse struct {
	Records []PunchRecord `json:"records"`
	Loading bool          `json:"loading"`
	Error   string        `json:"error"`
}

// DashboardResponse combines all dashboard data
type DashboardResponse struct {
	Stats   DashboardStats  `json:"stats"`
	Punches PunchesResponse `json:"punches"`
}

// FingerprintTransaction represents a row from hr_fingerprint_transactions
type FingerprintTransaction struct {
	EmployeeID string     `json:"employee_id" db:"employee_id"`
	Date       string     `json:"date" db:"date"`
	Time       string     `json:"time" db:"time"`
	Status     string     `json:"status" db:"status"`
	BranchID   *int64     `json:"branch_id" db:"branch_id"`
	DeviceID   *string    `json:"device_id" db:"device_id"`
	Location   *string    `json:"location" db:"location"`
	CreatedAt  *time.Time `json:"created_at" db:"created_at"`
}

// EmployeeInfo represents basic employee information
type EmployeeInfo struct {
	ID         string `json:"id" db:"id"`
	EmployeeID string `json:"employee_id" db:"employee_id"`
	BranchID   *int64 `json:"branch_id" db:"branch_id"`
}
