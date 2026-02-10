package server

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"

	"educonnect/internal/admin"
	"educonnect/internal/auth"
	"educonnect/internal/config"
	"educonnect/internal/course"
	"educonnect/internal/homework"
	"educonnect/internal/notification"
	"educonnect/internal/parent"
	"educonnect/internal/payment"
	"educonnect/internal/quiz"
	"educonnect/internal/review"
	searchmod "educonnect/internal/search"
	"educonnect/internal/session"
	"educonnect/internal/student"
	"educonnect/internal/teacher"
	"educonnect/internal/user"
	"educonnect/pkg/cache"
	"educonnect/pkg/database"
	"educonnect/pkg/livekit"
	"educonnect/pkg/messaging"
	"educonnect/pkg/search"
	"educonnect/pkg/storage"

	"github.com/gin-gonic/gin"
)

// Dependencies holds all external service connections.
type Dependencies struct {
	Config  *config.Config
	DB      *database.Postgres
	Cache   *cache.Redis
	MQ      *messaging.NATS
	Storage *storage.MinIO
	Search  *search.Meilisearch
	LiveKit *livekit.Client
}

// Server wraps the HTTP server and dependencies.
type Server struct {
	httpServer          *http.Server
	router              *gin.Engine
	deps                *Dependencies
	authHandler         *auth.Handler
	userHandler         *user.Handler
	teacherHandler      *teacher.Handler
	studentHandler      *student.Handler
	parentHandler       *parent.Handler
	sessionHandler      *session.Handler
	searchHandler       *searchmod.Handler
	courseHandler       *course.Handler
	homeworkHandler     *homework.Handler
	quizHandler         *quiz.Handler
	reviewHandler       *review.Handler
	notificationHandler *notification.Handler
	paymentHandler      *payment.Handler
	adminHandler        *admin.Handler
}

// New creates a new Server instance and sets up routes.
func New(deps *Dependencies) *Server {
	if deps.Config.App.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Initialize services and handlers
	authService := auth.NewService(deps.DB, deps.Cache, deps.Config, deps.Search)
	authHandler := auth.NewHandler(authService)

	userService := user.NewService(deps.DB, deps.Cache, deps.Storage)
	userHandler := user.NewHandler(userService)

	teacherService := teacher.NewService(deps.DB, deps.Search)
	teacherHandler := teacher.NewHandler(teacherService)

	studentService := student.NewService(deps.DB)
	studentHandler := student.NewHandler(studentService)

	parentService := parent.NewService(deps.DB)
	parentHandler := parent.NewHandler(parentService)

	sessionService := session.NewService(deps.DB, deps.LiveKit)
	sessionHandler := session.NewHandler(sessionService)

	searchService := searchmod.NewService(deps.Search)
	searchHandler := searchmod.NewHandler(searchService)

	courseService := course.NewService(deps.DB, deps.Storage)
	courseHandler := course.NewHandler(courseService)

	homeworkService := homework.NewService(deps.DB)
	homeworkHandler := homework.NewHandler(homeworkService)

	quizService := quiz.NewService(deps.DB)
	quizHandler := quiz.NewHandler(quizService)

	reviewService := review.NewService(deps.DB)
	reviewHandler := review.NewHandler(reviewService)

	notificationService := notification.NewService(deps.DB)
	notificationHandler := notification.NewHandler(notificationService)

	paymentService := payment.NewService(deps.DB)
	paymentHandler := payment.NewHandler(paymentService)

	adminService := admin.NewService(deps.DB)
	adminHandler := admin.NewHandler(adminService)

	s := &Server{
		router:              router,
		deps:                deps,
		authHandler:         authHandler,
		userHandler:         userHandler,
		teacherHandler:      teacherHandler,
		studentHandler:      studentHandler,
		parentHandler:       parentHandler,
		sessionHandler:      sessionHandler,
		searchHandler:       searchHandler,
		courseHandler:       courseHandler,
		homeworkHandler:     homeworkHandler,
		quizHandler:         quizHandler,
		reviewHandler:       reviewHandler,
		notificationHandler: notificationHandler,
		paymentHandler:      paymentHandler,
		adminHandler:        adminHandler,
		httpServer: &http.Server{
			Addr:    fmt.Sprintf(":%s", deps.Config.App.Port),
			Handler: router,
		},
	}

	s.setupRoutes()

	// Sync existing teachers to Meilisearch on startup
	go s.syncTeachersToSearch()

	return s
}

// Start begins listening for HTTP requests.
func (s *Server) Start() error {
	return s.httpServer.ListenAndServe()
}

// Shutdown gracefully stops the server.
func (s *Server) Shutdown(ctx context.Context) error {
	return s.httpServer.Shutdown(ctx)
}

// syncTeachersToSearch indexes all teachers into Meilisearch at startup.
func (s *Server) syncTeachersToSearch() {
	if s.deps.Search == nil {
		return
	}
	ctx := context.Background()
	rows, err := s.deps.DB.Pool.Query(ctx,
		`SELECT tp.user_id, u.first_name, u.last_name, COALESCE(u.wilaya,''),
		        COALESCE(tp.bio,''), tp.rating_avg, tp.total_sessions
		 FROM teacher_profiles tp
		 JOIN users u ON u.id = tp.user_id
		 WHERE u.is_active = true`)
	if err != nil {
		slog.Warn("sync teachers to search failed", "error", err)
		return
	}
	defer rows.Close()

	var docs []interface{}
	for rows.Next() {
		var id, firstName, lastName, wilaya, bio string
		var ratingAvg float64
		var totalSessions int
		if err := rows.Scan(&id, &firstName, &lastName, &wilaya, &bio, &ratingAvg, &totalSessions); err != nil {
			continue
		}
		docs = append(docs, map[string]interface{}{
			"id":             id,
			"name":           firstName + " " + lastName,
			"first_name":     firstName,
			"last_name":      lastName,
			"wilaya":         wilaya,
			"bio":            bio,
			"rating_avg":     ratingAvg,
			"total_sessions": totalSessions,
		})
	}
	if len(docs) > 0 {
		_, err := s.deps.Search.Client.Index("teachers").AddDocuments(docs)
		if err != nil {
			slog.Warn("failed to index teachers", "error", err)
		} else {
			slog.Info("synced teachers to search", "count", len(docs))
		}
	}
}
