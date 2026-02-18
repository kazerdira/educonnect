package search

import (
	"context"
	"fmt"
	"strings"

	pkgsearch "educonnect/pkg/search"

	"github.com/meilisearch/meilisearch-go"
)

type Service struct {
	meili *pkgsearch.Meilisearch
}

func NewService(meili *pkgsearch.Meilisearch) *Service {
	return &Service{meili: meili}
}

// SearchTeachers searches the "teachers" index.
func (s *Service) SearchTeachers(ctx context.Context, req SearchRequest) (*SearchResult, error) {
	if req.Page < 1 {
		req.Page = 1
	}
	if req.Limit < 1 || req.Limit > 50 {
		req.Limit = 20
	}

	filter := buildTeacherFilter(req)
	offset := int64((req.Page - 1) * req.Limit)

	opts := &meilisearch.SearchRequest{
		Offset: offset,
		Limit:  int64(req.Limit),
	}
	if filter != "" {
		opts.Filter = filter
	}

	hits, err := s.meili.SearchTeachers(req.Query, opts)
	if err != nil {
		return nil, fmt.Errorf("search teachers: %w", err)
	}

	return &SearchResult{
		Hits:             hits.Hits,
		TotalHits:        hits.EstimatedTotalHits,
		Page:             req.Page,
		Limit:            req.Limit,
		ProcessingTimeMs: hits.ProcessingTimeMs,
	}, nil
}

// SearchCourses searches the "courses" index.
func (s *Service) SearchCourses(ctx context.Context, req SearchRequest) (*SearchResult, error) {
	if req.Page < 1 {
		req.Page = 1
	}
	if req.Limit < 1 || req.Limit > 50 {
		req.Limit = 20
	}

	filter := buildCourseFilter(req)
	offset := int64((req.Page - 1) * req.Limit)

	opts := &meilisearch.SearchRequest{
		Offset: offset,
		Limit:  int64(req.Limit),
	}
	if filter != "" {
		opts.Filter = filter
	}

	hits, err := s.meili.SearchCourses(req.Query, opts)
	if err != nil {
		return nil, fmt.Errorf("search courses: %w", err)
	}

	return &SearchResult{
		Hits:             hits.Hits,
		TotalHits:        hits.EstimatedTotalHits,
		Page:             req.Page,
		Limit:            req.Limit,
		ProcessingTimeMs: hits.ProcessingTimeMs,
	}, nil
}

// buildTeacherFilter uses array fields (subjects, levels) because a teacher
// can have many offerings → many subjects/levels.
func buildTeacherFilter(req SearchRequest) string {
	var parts []string
	if req.Level != "" {
		parts = append(parts, fmt.Sprintf("levels = %q", req.Level))
	}
	if req.Subject != "" {
		parts = append(parts, fmt.Sprintf("subjects = %q", req.Subject))
	}
	if req.Wilaya != "" {
		parts = append(parts, fmt.Sprintf("wilaya = %q", req.Wilaya))
	}
	if req.MinPrice > 0 {
		parts = append(parts, fmt.Sprintf("price_min >= %f", req.MinPrice))
	}
	if req.MaxPrice > 0 {
		parts = append(parts, fmt.Sprintf("price_max <= %f", req.MaxPrice))
	}
	return strings.Join(parts, " AND ")
}

// buildCourseFilter uses singular fields matching the courses index.
func buildCourseFilter(req SearchRequest) string {
	var parts []string
	if req.Level != "" {
		parts = append(parts, fmt.Sprintf("level = %q", req.Level))
	}
	if req.Subject != "" {
		parts = append(parts, fmt.Sprintf("subject = %q", req.Subject))
	}
	if req.MinPrice > 0 {
		parts = append(parts, fmt.Sprintf("price >= %f", req.MinPrice))
	}
	if req.MaxPrice > 0 {
		parts = append(parts, fmt.Sprintf("price <= %f", req.MaxPrice))
	}
	return strings.Join(parts, " AND ")
}
