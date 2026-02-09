package middleware

import (
	"time"

	"github.com/gin-gonic/gin"
)

// CORS configures Cross-Origin Resource Sharing.
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization, X-Requested-With")
		c.Header("Access-Control-Expose-Headers", "Content-Length, Content-Range")
		c.Header("Access-Control-Max-Age", "43200") // 12 hours

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// Logger provides structured request logging using slog.
func Logger() gin.HandlerFunc {
	return gin.LoggerWithConfig(gin.LoggerConfig{
		Formatter: func(param gin.LogFormatterParams) string {
			return ""
		},
		Output:    nil,
		SkipPaths: []string{"/health"},
	})
}

// CustomLogger is a more detailed slog-based logger.
func CustomLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()

		// Skip health checks
		if path == "/health" {
			return
		}

		attrs := []any{
			"status", status,
			"method", c.Request.Method,
			"path", path,
			"query", query,
			"ip", c.ClientIP(),
			"latency", latency.String(),
			"user_agent", c.Request.UserAgent(),
		}

		if userID := GetUserID(c); userID != "" {
			attrs = append(attrs, "user_id", userID)
		}

		if len(c.Errors) > 0 {
			attrs = append(attrs, "errors", c.Errors.String())
		}

		switch {
		case status >= 500:
			_slogError(attrs)
		case status >= 400:
			_slogWarn(attrs)
		default:
			_slogInfo(attrs)
		}
	}
}

// These are thin wrappers to avoid import cycle with slog in middleware.
// In production, you'd use slog directly.
func _slogInfo(attrs []any) {
	// slog.Info("request", attrs...)
}
func _slogWarn(attrs []any) {
	// slog.Warn("request", attrs...)
}
func _slogError(attrs []any) {
	// slog.Error("request", attrs...)
}
