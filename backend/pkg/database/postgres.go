package database

import (
	"context"
	"time"

	"educonnect/internal/config"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Postgres wraps the pgx connection pool.
type Postgres struct {
	Pool *pgxpool.Pool
}

// NewPostgres creates a new PostgreSQL connection pool.
func NewPostgres(cfg config.DatabaseConfig) (*Postgres, error) {
	poolConfig, err := pgxpool.ParseConfig(cfg.DSN())
	if err != nil {
		return nil, err
	}

	// Connection pool settings
	poolConfig.MaxConns = 25
	poolConfig.MinConns = 5
	poolConfig.MaxConnLifetime = 30 * time.Minute
	poolConfig.MaxConnIdleTime = 5 * time.Minute
	poolConfig.HealthCheckPeriod = 1 * time.Minute

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		return nil, err
	}

	// Verify the connection
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}

	return &Postgres{Pool: pool}, nil
}

// Close closes the connection pool.
func (p *Postgres) Close() {
	p.Pool.Close()
}

// Health checks if the database connection is alive.
func (p *Postgres) Health(ctx context.Context) error {
	return p.Pool.Ping(ctx)
}
