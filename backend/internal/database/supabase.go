package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"
)

var DB *sql.DB

// InitDB initializes the database connection
func InitDB() error {
	var err error
	
	// Get database configuration from environment
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")
	user := os.Getenv("DB_USER")
	password := os.Getenv("DB_PASSWORD")
	dbname := os.Getenv("DB_NAME")
	
	log.Printf("Raw environment variables - DB_PASSWORD: '%s'", password)
	
	// Hardcode password temporarily for testing
	if password == "" {
		password = "@#Imanihayath120"
		log.Printf("Using hardcoded password")
	}
	
	if host == "" {
		host = "db.vmypotfsyrvuublyddyt.supabase.co"
	}
	if port == "" {
		port = "5432"
	}
	if user == "" {
		user = "postgres"
	}
	if dbname == "" {
		dbname = "postgres"
	}
	
	// Build connection string
	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		host, port, user, password, dbname)
	
	log.Printf("Connecting to database with host: %s, port: %s, user: %s, dbname: %s", host, port, user, dbname)
	log.Printf("Password length: %d characters", len(password))
	
	// Open database connection
	DB, err = sql.Open("postgres", psqlInfo)
	if err != nil {
		return fmt.Errorf("failed to open database connection: %v", err)
	}
	
	// Test the connection
	err = DB.Ping()
	if err != nil {
		return fmt.Errorf("failed to ping database: %v", err)
	}
	
	log.Println("✅ Successfully connected to Supabase database")
	return nil
}

// CloseDB closes the database connection
func CloseDB() {
	if DB != nil {
		DB.Close()
		log.Println("Database connection closed")
	}
}

// GetDB returns the database connection
func GetDB() *sql.DB {
	return DB
}
