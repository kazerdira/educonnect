package server

import "github.com/gin-gonic/gin"

// Response is the standard API response envelope.
type Response struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   *ErrorInfo  `json:"error,omitempty"`
	Meta    *Meta       `json:"meta,omitempty"`
}

// ErrorInfo holds error details.
type ErrorInfo struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

// Meta holds pagination information.
type Meta struct {
	Page    int   `json:"page"`
	Limit   int   `json:"limit"`
	Total   int64 `json:"total"`
	HasMore bool  `json:"has_more"`
}

// ─── Response Helpers ───────────────────────────────────────────

func respondOK(c *gin.Context, data interface{}) {
	c.JSON(200, Response{Success: true, Data: data})
}

func respondCreated(c *gin.Context, data interface{}) {
	c.JSON(201, Response{Success: true, Data: data})
}

func respondPaginated(c *gin.Context, data interface{}, meta *Meta) {
	c.JSON(200, Response{Success: true, Data: data, Meta: meta})
}

func respondError(c *gin.Context, status int, code, message string) {
	c.JSON(status, Response{
		Success: false,
		Error:   &ErrorInfo{Code: code, Message: message},
	})
}

func respondValidationError(c *gin.Context, details interface{}) {
	c.JSON(422, Response{
		Success: false,
		Error: &ErrorInfo{
			Code:    "VALIDATION_ERROR",
			Message: "The provided data is invalid",
			Details: details,
		},
	})
}
