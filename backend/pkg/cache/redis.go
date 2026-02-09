package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"educonnect/internal/config"

	"github.com/redis/go-redis/v9"
)

// Redis wraps the Redis client with helper methods.
type Redis struct {
	Client *redis.Client
}

// NewRedis creates a new Redis client.
func NewRedis(cfg config.RedisConfig) (*Redis, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     cfg.Addr(),
		Password: cfg.Password,
		DB:       cfg.DB,

		PoolSize:     50,
		MinIdleConns: 10,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("redis ping failed: %w", err)
	}

	return &Redis{Client: client}, nil
}

// Close closes the Redis connection.
func (r *Redis) Close() error {
	return r.Client.Close()
}

// ─── Key Helpers ────────────────────────────────────────────────

const (
	PrefixOTP     = "otp:"
	PrefixSession = "session:"
	PrefixRefresh = "refresh:"
	PrefixRate    = "rate:"
)

// ─── OTP Operations ─────────────────────────────────────────────

// SetOTP stores an OTP code with expiration.
func (r *Redis) SetOTP(ctx context.Context, phone, code string, expiry time.Duration) error {
	return r.Client.Set(ctx, PrefixOTP+phone, code, expiry).Err()
}

// GetOTP retrieves an OTP code.
func (r *Redis) GetOTP(ctx context.Context, phone string) (string, error) {
	return r.Client.Get(ctx, PrefixOTP+phone).Result()
}

// DeleteOTP removes an OTP code after verification.
func (r *Redis) DeleteOTP(ctx context.Context, phone string) error {
	return r.Client.Del(ctx, PrefixOTP+phone).Err()
}

// IncrOTPAttempts increments OTP attempt counter.
func (r *Redis) IncrOTPAttempts(ctx context.Context, phone string) (int64, error) {
	key := PrefixOTP + phone + ":attempts"
	pipe := r.Client.TxPipeline()
	incr := pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, 10*time.Minute)
	_, err := pipe.Exec(ctx)
	return incr.Val(), err
}

// ─── Generic Cache ──────────────────────────────────────────────

// Set stores a value as JSON with expiration.
func (r *Redis) Set(ctx context.Context, key string, value interface{}, expiry time.Duration) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return r.Client.Set(ctx, key, data, expiry).Err()
}

// Get retrieves a JSON value and unmarshals into target.
func (r *Redis) Get(ctx context.Context, key string, target interface{}) error {
	data, err := r.Client.Get(ctx, key).Bytes()
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

// Delete removes a key.
func (r *Redis) Delete(ctx context.Context, key string) error {
	return r.Client.Del(ctx, key).Err()
}

// Exists checks if a key exists.
func (r *Redis) Exists(ctx context.Context, key string) (bool, error) {
	n, err := r.Client.Exists(ctx, key).Result()
	return n > 0, err
}
