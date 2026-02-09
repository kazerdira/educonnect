package search

// SearchRequest holds search params.
type SearchRequest struct {
	Query    string  `form:"q"    binding:"required,min=2"`
	Page     int     `form:"page"`
	Limit    int     `form:"limit"`
	Level    string  `form:"level"`
	Subject  string  `form:"subject"`
	Wilaya   string  `form:"wilaya"`
	MinPrice float64 `form:"min_price"`
	MaxPrice float64 `form:"max_price"`
}

// SearchResult is a generic search response wrapping Meilisearch output.
type SearchResult struct {
	Hits             interface{} `json:"hits"`
	TotalHits        int64       `json:"total_hits"`
	Page             int         `json:"page"`
	Limit            int         `json:"limit"`
	ProcessingTimeMs int64       `json:"processing_time_ms"`
}
