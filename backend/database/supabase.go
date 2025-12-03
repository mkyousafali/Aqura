package database

import (
	"database/sql"
	"fmt"
	"log"
	"net"
	"os"
	"strings"
	"time"

	"github.com/lib/pq"
)

var DB *sql.DB

// resolveToIPv4 resolves hostname to IPv4 address only
func resolveToIPv4(host string) (string, error) {
	ips, err := net.LookupIP(host)
	if err != nil {
		return "", err
	}
	
	for _, ip := range ips {
		if ipv4 := ip.To4(); ipv4 != nil {
			return ipv4.String(), nil
		}
	}
	
	return "", fmt.Errorf("no IPv4 address found for %s", host)
}

// InitDB initializes the database connection to Supabase PostgreSQL
func InitDB() error {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return fmt.Errorf("DATABASE_URL environment variable is not set")
	}

	// Force IPv4 by resolving hostname to IP
	if strings.Contains(dbURL, "supabase.com") {
		// Extract hostname from connection string
		var host string
		if strings.Contains(dbURL, "pooler.supabase.com") {
			host = "aws-0-ap-south-1.pooler.supabase.com"
		} else {
			host = "db.vmypotfsyrvuublyddyt.supabase.co"
		}
		
		ipv4, err := resolveToIPv4(host)
		if err != nil {
			log.Printf("⚠️  Failed to resolve %s to IPv4: %v", host, err)
		} else {
			log.Printf("🔄 Resolved %s to IPv4: %s", host, ipv4)
			dbURL = strings.Replace(dbURL, host, ipv4, 1)
		}
	}

	var err error
	DB, err = sql.Open("postgres", dbURL)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}

	// Configure connection pool
	DB.SetMaxOpenConns(25)
	DB.SetMaxIdleConns(5)
	DB.SetConnMaxLifetime(5 * time.Minute)

	// Test the connection
	if err = DB.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	log.Println("✅ Successfully connected to Supabase PostgreSQL")
	return nil
}

// CloseDB closes the database connection
func CloseDB() error {
	if DB != nil {
		return DB.Close()
	}
	return nil
}

// GetDB returns the database instance
func GetDB() *sql.DB {
	return DB
}

// NotificationCallback is called when a database notification is received
type NotificationCallback func(channel string, payload string)

// StartNotificationListener starts listening for PostgreSQL NOTIFY events
func StartNotificationListener(callback NotificationCallback) error {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return fmt.Errorf("DATABASE_URL environment variable is not set")
	}

	// Create a new listener
	reportProblem := func(ev pq.ListenerEventType, err error) {
		if err != nil {
			log.Printf("⚠️ Listener error: %v", err)
		}
	}

	listener := pq.NewListener(
		dbURL,
		10*time.Second,  // minReconnectInterval
		time.Minute,     // maxReconnectInterval
		reportProblem,
	)

	// Listen to channels
	channels := []string{
		"branches_changed",
		"erp_daily_sales_changed",
		"cache_invalidate",
	}

	for _, channel := range channels {
		err := listener.Listen(channel)
		if err != nil {
			return fmt.Errorf("failed to listen to %s: %w", channel, err)
		}
		log.Printf("🔔 Listening for notifications on channel: %s", channel)
	}

	// Start listening in background
	go func() {
		for {
			select {
			case notification := <-listener.Notify:
				if notification != nil {
					log.Printf("📢 Received notification on %s: %s", notification.Channel, notification.Extra)
					if callback != nil {
						callback(notification.Channel, notification.Extra)
					}
				}
			case <-time.After(90 * time.Second):
				// Send periodic pings to keep connection alive
				go func() {
					err := listener.Ping()
					if err != nil {
						log.Printf("⚠️ Listener ping failed: %v", err)
					}
				}()
			}
		}
	}()

	log.Println("✅ Notification listener started successfully")
	return nil
}
