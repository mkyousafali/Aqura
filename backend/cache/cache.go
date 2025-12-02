package cache

import (
	"sync"
	"time"
)

type CacheItem struct {
	Data      interface{}
	ExpiresAt time.Time
}

type Cache struct {
	items map[string]*CacheItem
	mu    sync.RWMutex
}

var globalCache = &Cache{
	items: make(map[string]*CacheItem),
}

// Get retrieves an item from cache
func Get(key string) (interface{}, bool) {
	globalCache.mu.RLock()
	defer globalCache.mu.RUnlock()

	item, exists := globalCache.items[key]
	if !exists {
		return nil, false
	}

	// Check if expired
	if time.Now().After(item.ExpiresAt) {
		return nil, false
	}

	return item.Data, true
}

// Set adds an item to cache with expiration
func Set(key string, data interface{}, ttl time.Duration) {
	globalCache.mu.Lock()
	defer globalCache.mu.Unlock()

	globalCache.items[key] = &CacheItem{
		Data:      data,
		ExpiresAt: time.Now().Add(ttl),
	}
}

// Invalidate removes an item from cache
func Invalidate(key string) {
	globalCache.mu.Lock()
	defer globalCache.mu.Unlock()

	delete(globalCache.items, key)
}

// Clear removes all items from cache
func Clear() {
	globalCache.mu.Lock()
	defer globalCache.mu.Unlock()

	globalCache.items = make(map[string]*CacheItem)
}
