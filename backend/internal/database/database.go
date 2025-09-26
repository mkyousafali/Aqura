package database

import (
	"fmt"
	"log"
	"os"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

// Branch model that matches our database schema
type Branch struct {
	ID           int64     `json:"id" gorm:"column:id;primaryKey;autoIncrement"`
	NameEn       string    `json:"name_en" gorm:"column:name_en;not null"`
	NameAr       string    `json:"name_ar" gorm:"column:name_ar;not null"`
	LocationEn   string    `json:"location_en" gorm:"column:location_en;not null"`
	LocationAr   string    `json:"location_ar" gorm:"column:location_ar;not null"`
	IsActive     bool      `json:"is_active" gorm:"column:is_active;default:true"`
	IsMainBranch bool      `json:"is_main_branch" gorm:"column:is_main_branch;default:false"`
	CreatedAt    time.Time `json:"created_at" gorm:"column:created_at;autoCreateTime"`
	UpdatedAt    time.Time `json:"updated_at" gorm:"column:updated_at;autoUpdateTime"`
	CreatedBy    *int64    `json:"created_by,omitempty" gorm:"column:created_by"`
	UpdatedBy    *int64    `json:"updated_by,omitempty" gorm:"column:updated_by"`
}

// TableName specifies the table name for GORM
func (Branch) TableName() string {
	return "branches"
}

// Connect establishes database connection
func Connect() {
	host := os.Getenv("DB_HOST")
	if host == "" {
		host = "localhost"
	}
	
	port := os.Getenv("DB_PORT")
	if port == "" {
		port = "5432"
	}
	
	dbname := os.Getenv("DB_NAME")
	if dbname == "" {
		dbname = "aqura"
	}
	
	user := os.Getenv("DB_USER")
	if user == "" {
		user = "postgres"
	}
	
	password := os.Getenv("DB_PASSWORD")
	if password == "" {
		password = "password"
	}

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require TimeZone=UTC",
		host, port, user, password, dbname)

	var err error
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Printf("Failed to connect to database: %v", err)
		log.Println("Continuing without database connection...")
		return
	}

	// Test the connection
	sqlDB, err := DB.DB()
	if err != nil {
		log.Printf("Failed to get database instance: %v", err)
		return
	}

	if err := sqlDB.Ping(); err != nil {
		log.Printf("Failed to ping database: %v", err)
		return
	}

	log.Println("✅ Successfully connected to PostgreSQL database")
}