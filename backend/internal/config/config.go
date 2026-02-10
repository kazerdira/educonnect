package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config holds all application configuration.
type Config struct {
	App         AppConfig
	Database    DatabaseConfig
	Redis       RedisConfig
	NATS        NATSConfig
	MinIO       MinIOConfig
	Meilisearch MeilisearchConfig
	LiveKit     LiveKitConfig
	JWT         JWTConfig
	SMS         SMSConfig
	Platform    PlatformConfig
}

type AppConfig struct {
	Env  string
	Port string
	URL  string
}

type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

func (d DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		d.User, d.Password, d.Host, d.Port, d.DBName, d.SSLMode,
	)
}

type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

func (r RedisConfig) Addr() string {
	return fmt.Sprintf("%s:%s", r.Host, r.Port)
}

type NATSConfig struct {
	URL      string
	User     string
	Password string
}

type MinIOConfig struct {
	Endpoint         string
	AccessKey        string
	SecretKey        string
	UseSSL           bool
	BucketAvatars    string
	BucketDocuments  string
	BucketVideos     string
	BucketRecordings string
}

type MeilisearchConfig struct {
	Host      string
	MasterKey string
}

type LiveKitConfig struct {
	Host      string
	APIKey    string
	APISecret string
}

type JWTConfig struct {
	Secret        string
	AccessExpiry  time.Duration
	RefreshExpiry time.Duration
}

type SMSConfig struct {
	Provider      string
	ICOSNETKey    string
	ICOSNETSecret string
	TwilioSID     string
	TwilioToken   string
	TwilioFrom    string
}

type PlatformConfig struct {
	CommissionRate  float64
	DefaultLanguage string
}

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	cfg := &Config{
		App: AppConfig{
			Env:  getEnv("APP_ENV", "development"),
			Port: getEnv("APP_PORT", "8080"),
			URL:  getEnv("APP_URL", "http://localhost:8080"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("POSTGRES_HOST", "localhost"),
			Port:     getEnv("POSTGRES_PORT", "5432"),
			User:     getEnv("POSTGRES_USER", "educonnect"),
			Password: getEnv("POSTGRES_PASSWORD", "educonnect_secret"),
			DBName:   getEnv("POSTGRES_DB", "educonnect"),
			SSLMode:  getEnv("POSTGRES_SSL_MODE", "disable"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", "educonnect_redis"),
			DB:       getEnvInt("REDIS_DB", 0),
		},
		NATS: NATSConfig{
			URL:      getEnv("NATS_URL", "nats://localhost:4222"),
			User:     getEnv("NATS_USER", "educonnect"),
			Password: getEnv("NATS_PASSWORD", "educonnect_nats"),
		},
		MinIO: MinIOConfig{
			Endpoint:         getEnv("MINIO_ENDPOINT", "localhost:9000"),
			AccessKey:        getEnv("MINIO_ACCESS_KEY", "educonnect_minio"),
			SecretKey:        getEnv("MINIO_SECRET_KEY", "educonnect_minio_secret"),
			UseSSL:           getEnvBool("MINIO_USE_SSL", false),
			BucketAvatars:    getEnv("MINIO_BUCKET_AVATARS", "avatars"),
			BucketDocuments:  getEnv("MINIO_BUCKET_DOCUMENTS", "documents"),
			BucketVideos:     getEnv("MINIO_BUCKET_VIDEOS", "videos"),
			BucketRecordings: getEnv("MINIO_BUCKET_RECORDINGS", "recordings"),
		},
		Meilisearch: MeilisearchConfig{
			Host:      getEnv("MEILI_HOST", "http://localhost:7700"),
			MasterKey: getEnv("MEILI_MASTER_KEY", "educonnect_meili_key"),
		},
		LiveKit: LiveKitConfig{
			Host:      getEnv("LIVEKIT_HOST", "http://localhost:7880"),
			APIKey:    getEnv("LIVEKIT_API_KEY", "devkey"),
			APISecret: getEnv("LIVEKIT_API_SECRET", "secret_that_is_at_least_32_characters_long"),
		},
		JWT: JWTConfig{
			Secret:        getEnv("JWT_SECRET", "your_jwt_secret_key_change_in_production"),
			AccessExpiry:  getEnvDuration("JWT_ACCESS_EXPIRY", 24*time.Hour),
			RefreshExpiry: getEnvDuration("JWT_REFRESH_EXPIRY", 30*24*time.Hour),
		},
		SMS: SMSConfig{
			Provider:      getEnv("SMS_PROVIDER", "icosnet"),
			ICOSNETKey:    getEnv("ICOSNET_API_KEY", ""),
			ICOSNETSecret: getEnv("ICOSNET_API_SECRET", ""),
			TwilioSID:     getEnv("TWILIO_ACCOUNT_SID", ""),
			TwilioToken:   getEnv("TWILIO_AUTH_TOKEN", ""),
			TwilioFrom:    getEnv("TWILIO_FROM_NUMBER", ""),
		},
		Platform: PlatformConfig{
			CommissionRate:  getEnvFloat("PLATFORM_COMMISSION_RATE", 0.20),
			DefaultLanguage: getEnv("PLATFORM_DEFAULT_LANGUAGE", "fr"),
		},
	}

	return cfg, nil
}

// ─── Helpers ────────────────────────────────────────────────────

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if val := os.Getenv(key); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			return i
		}
	}
	return fallback
}

func getEnvBool(key string, fallback bool) bool {
	if val := os.Getenv(key); val != "" {
		if b, err := strconv.ParseBool(val); err == nil {
			return b
		}
	}
	return fallback
}

func getEnvFloat(key string, fallback float64) float64 {
	if val := os.Getenv(key); val != "" {
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			return f
		}
	}
	return fallback
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
	if val := os.Getenv(key); val != "" {
		if d, err := time.ParseDuration(val); err == nil {
			return d
		}
	}
	return fallback
}
