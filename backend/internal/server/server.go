package server

import (
	"context"
	"fmt"
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
	authService := auth.NewService(deps.DB, deps.Cache, deps.Config)
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
