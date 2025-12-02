package models

import (
	"database/sql"
	"encoding/json"
)

// NullString wraps sql.NullString to provide proper JSON marshaling
// This is a common type used across all interfaces
type NullString struct {
	sql.NullString
}

// MarshalJSON converts NullString to JSON, returning null or string value
func (ns NullString) MarshalJSON() ([]byte, error) {
	if !ns.Valid {
		return []byte("null"), nil
	}
	return json.Marshal(ns.String)
}

// UnmarshalJSON parses JSON into NullString
func (ns *NullString) UnmarshalJSON(data []byte) error {
	var s *string
	if err := json.Unmarshal(data, &s); err != nil {
		return err
	}
	if s != nil {
		ns.Valid = true
		ns.String = *s
	} else {
		ns.Valid = false
	}
	return nil
}
