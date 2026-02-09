# ╔══════════════════════════════════════════════════════════════╗
# ║  EduConnect — Makefile                                     ║
# ╚══════════════════════════════════════════════════════════════╝

.PHONY: help dev infra infra-down migrate-up migrate-down sqlc build run test lint

# ─── Config ───────────────────────────────────────────────────
BACKEND_DIR := backend
MOBILE_DIR := mobile
BINARY := educonnect-api

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Infrastructure ──────────────────────────────────────────
infra: ## Start all infrastructure services
	docker-compose up -d

infra-down: ## Stop all infrastructure services
	docker-compose down

infra-logs: ## Tail infrastructure logs
	docker-compose logs -f

# ─── Backend ─────────────────────────────────────────────────
dev: ## Run backend with hot reload (requires air)
	cd $(BACKEND_DIR) && air

build: ## Build backend binary
	cd $(BACKEND_DIR) && go build -o bin/$(BINARY) ./cmd/api

run: ## Run backend binary
	cd $(BACKEND_DIR) && go run ./cmd/api

test: ## Run backend tests
	cd $(BACKEND_DIR) && go test -v -race ./...

lint: ## Lint backend code
	cd $(BACKEND_DIR) && golangci-lint run ./...

# ─── Database ────────────────────────────────────────────────
migrate-up: ## Run all pending migrations
	cd $(BACKEND_DIR) && goose -dir db/migrations postgres "$(DATABASE_URL)" up

migrate-down: ## Rollback last migration
	cd $(BACKEND_DIR) && goose -dir db/migrations postgres "$(DATABASE_URL)" down

migrate-create: ## Create a new migration (usage: make migrate-create NAME=create_users)
	cd $(BACKEND_DIR) && goose -dir db/migrations create $(NAME) sql

migrate-status: ## Show migration status
	cd $(BACKEND_DIR) && goose -dir db/migrations postgres "$(DATABASE_URL)" status

sqlc: ## Generate Go code from SQL queries
	cd $(BACKEND_DIR) && sqlc generate

# ─── Flutter ─────────────────────────────────────────────────
mobile-run: ## Run Flutter app
	cd $(MOBILE_DIR) && flutter run

mobile-build-apk: ## Build Android APK
	cd $(MOBILE_DIR) && flutter build apk --release

mobile-build-ios: ## Build iOS
	cd $(MOBILE_DIR) && flutter build ios --release

mobile-gen: ## Run Flutter code generation (build_runner)
	cd $(MOBILE_DIR) && dart run build_runner build --delete-conflicting-outputs

mobile-test: ## Run Flutter tests
	cd $(MOBILE_DIR) && flutter test

# ─── Full Stack ──────────────────────────────────────────────
setup: ## First-time setup: start infra, run migrations, generate code
	@echo "🚀 Starting infrastructure..."
	$(MAKE) infra
	@echo "⏳ Waiting for services..."
	@sleep 10
	@echo "📦 Running migrations..."
	$(MAKE) migrate-up
	@echo "🔧 Generating sqlc code..."
	$(MAKE) sqlc
	@echo "✅ Setup complete!"
