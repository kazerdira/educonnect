package server

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"

	"educonnect/internal/admin"
	"educonnect/internal/auth"
	"educonnect/internal/booking"
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
	"educonnect/internal/sessionseries"
	"educonnect/internal/student"
	"educonnect/internal/teacher"
	"educonnect/internal/user"
	"educonnect/internal/wallet"
	"educonnect/pkg/cache"
	"educonnect/pkg/database"
	"educonnect/pkg/livekit"
	"educonnect/pkg/messaging"
	"educonnect/pkg/search"
	"educonnect/pkg/storage"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
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
	seriesHandler       *sessionseries.Handler
	bookingHandler      *booking.Handler
	walletHandler       *wallet.Handler
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

	walletService := wallet.NewService(deps.DB)
	walletHandler := wallet.NewHandler(walletService)

	seriesService := sessionseries.NewService(deps.DB, deps.LiveKit, walletService)
	seriesHandler := sessionseries.NewHandler(seriesService)

	bookingService := booking.NewService(deps.DB, notificationService)
	bookingHandler := booking.NewHandler(bookingService)

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
		seriesHandler:       seriesHandler,
		bookingHandler:      bookingHandler,
		walletHandler:       walletHandler,
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

		// Fetch subjects and levels from offerings
		subjects, levels, priceMin, priceMax := s.fetchTeacherOfferingsMeta(ctx, id)

		doc := map[string]interface{}{
			"id":             id,
			"name":           firstName + " " + lastName,
			"first_name":     firstName,
			"last_name":      lastName,
			"wilaya":         wilaya,
			"bio":            bio,
			"rating_avg":     ratingAvg,
			"total_sessions": totalSessions,
			"subjects":       subjects,
			"levels":         levels,
		}
		if priceMin > 0 {
			doc["price_min"] = priceMin
		}
		if priceMax > 0 {
			doc["price_max"] = priceMax
		}
		docs = append(docs, doc)
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

// fetchTeacherOfferingsMeta returns unique subject names, level names, min and max prices.
func (s *Server) fetchTeacherOfferingsMeta(ctx context.Context, teacherID string) ([]string, []string, float64, float64) {
	uid, _ := uuid.Parse(teacherID)
	rows, err := s.deps.DB.Pool.Query(ctx,
		`SELECT DISTINCT sub.name_fr, lvl.name, o.price_per_hour
		 FROM offerings o
		 JOIN subjects sub ON sub.id = o.subject_id
		 JOIN levels   lvl ON lvl.id = o.level_id
		 WHERE o.teacher_id = $1 AND o.is_active = true`, uid)
	if err != nil {
		return nil, nil, 0, 0
	}
	defer rows.Close()

	subjectSet := map[string]bool{}
	levelSet := map[string]bool{}
	var priceMin, priceMax float64
	for rows.Next() {
		var subName, lvlName string
		var price float64
		if err := rows.Scan(&subName, &lvlName, &price); err != nil {
			continue
		}
		subjectSet[subName] = true
		levelSet[lvlName] = true
		if priceMin == 0 || price < priceMin {
			priceMin = price
		}
		if price > priceMax {
			priceMax = price
		}
	}

	subjects := make([]string, 0, len(subjectSet))
	for s := range subjectSet {
		subjects = append(subjects, s)
	}
	levels := make([]string, 0, len(levelSet))
	for l := range levelSet {
		levels = append(levels, l)
	}
	return subjects, levels, priceMin, priceMax
}
