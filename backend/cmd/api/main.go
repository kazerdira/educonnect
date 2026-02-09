package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"educonnect/internal/config"
	"educonnect/internal/server"
	"educonnect/pkg/cache"
	"educonnect/pkg/database"
	"educonnect/pkg/livekit"
	"educonnect/pkg/messaging"
	"educonnect/pkg/search"
	"educonnect/pkg/storage"

	"github.com/joho/godotenv"
)

func main() {
	// ── Logger ──────────────────────────────────────────────────
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	// ── Load .env (development only) ────────────────────────────
	// Try multiple paths: project root (from cmd/api), or current dir
	for _, p := range []string{"../../.env", "../.env", ".env"} {
		if err := godotenv.Load(p); err == nil {
			break
		}
	}

	// ── Configuration ───────────────────────────────────────────
	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// ── Database (PostgreSQL) ───────────────────────────────────
	db, err := database.NewPostgres(cfg.Database)
	if err != nil {
		slog.Error("failed to connect to PostgreSQL", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	slog.Info("connected to PostgreSQL")

	// ── Cache (Redis) ───────────────────────────────────────────
	rdb, err := cache.NewRedis(cfg.Redis)
	if err != nil {
		slog.Error("failed to connect to Redis", "error", err)
		os.Exit(1)
	}
	defer rdb.Close()
	slog.Info("connected to Redis")

	// ── Message Queue (NATS) ────────────────────────────────────
	nc, err := messaging.NewNATS(cfg.NATS)
	if err != nil {
		slog.Error("failed to connect to NATS", "error", err)
		os.Exit(1)
	}
	defer nc.Close()
	slog.Info("connected to NATS")

	// ── Object Storage (MinIO) ──────────────────────────────────
	store, err := storage.NewMinIO(cfg.MinIO)
	if err != nil {
		slog.Error("failed to connect to MinIO", "error", err)
		os.Exit(1)
	}
	slog.Info("connected to MinIO")

	// ── Search (Meilisearch) ────────────────────────────────────
	searchClient := search.NewMeilisearch(cfg.Meilisearch)
	slog.Info("connected to Meilisearch")

	// ── LiveKit ─────────────────────────────────────────────────
	lkClient := livekit.NewClient(cfg.LiveKit)
	slog.Info("LiveKit client initialized")

	// ── Server ──────────────────────────────────────────────────
	deps := &server.Dependencies{
		Config:  cfg,
		DB:      db,
		Cache:   rdb,
		MQ:      nc,
		Storage: store,
		Search:  searchClient,
		LiveKit: lkClient,
	}

	srv := server.New(deps)

	// ── Graceful shutdown ───────────────────────────────────────
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		slog.Info("starting server", "port", cfg.App.Port)
		if err := srv.Start(); err != nil {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	<-quit
	slog.Info("shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("server forced to shutdown", "error", err)
	}

	slog.Info("server stopped")
}
