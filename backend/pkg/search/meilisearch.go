package search

import (
	"educonnect/internal/config"

	"github.com/meilisearch/meilisearch-go"
)

// Index names.
const (
	IndexTeachers = "teachers"
	IndexCourses  = "courses"
	IndexSubjects = "subjects"
)

// Meilisearch wraps the Meilisearch client.
type Meilisearch struct {
	Client *meilisearch.Client
}

// NewMeilisearch creates a new Meilisearch client and configures indexes.
func NewMeilisearch(cfg config.MeilisearchConfig) *Meilisearch {
	client := meilisearch.NewClient(meilisearch.ClientConfig{
		Host:   cfg.Host,
		APIKey: cfg.MasterKey,
	})

	m := &Meilisearch{Client: client}

	// Configure indexes (best-effort at startup)
	m.configureIndexes()

	return m
}

// configureIndexes sets up search indexes with proper settings.
func (m *Meilisearch) configureIndexes() {
	// Teachers index
	m.Client.CreateIndex(&meilisearch.IndexConfig{
		Uid:        IndexTeachers,
		PrimaryKey: "id",
	})
	teacherIdx := m.Client.Index(IndexTeachers)
	teacherIdx.UpdateFilterableAttributes(&[]string{
		"subjects", "levels", "wilaya", "verification_status",
		"session_type", "price_min", "price_max", "rating",
		"language",
	})
	teacherIdx.UpdateSortableAttributes(&[]string{
		"rating", "total_sessions", "price_min", "created_at",
	})
	teacherIdx.UpdateSearchableAttributes(&[]string{
		"name", "first_name", "last_name", "bio", "specializations", "wilaya",
		"subjects", "levels",
	})

	// Courses index
	m.Client.CreateIndex(&meilisearch.IndexConfig{
		Uid:        IndexCourses,
		PrimaryKey: "id",
	})
	courseIdx := m.Client.Index(IndexCourses)
	courseIdx.UpdateFilterableAttributes(&[]string{
		"subject", "level", "teacher_id", "price", "is_free",
	})
	courseIdx.UpdateSortableAttributes(&[]string{
		"price", "created_at", "enrollment_count",
	})
	courseIdx.UpdateSearchableAttributes(&[]string{
		"title", "description", "subject", "level", "teacher_name",
	})
}

// IndexTeacher adds or updates a teacher in the search index.
func (m *Meilisearch) IndexTeacher(doc interface{}) error {
	_, err := m.Client.Index(IndexTeachers).AddDocuments([]interface{}{doc})
	return err
}

// IndexCourse adds or updates a course in the search index.
func (m *Meilisearch) IndexCourse(doc interface{}) error {
	_, err := m.Client.Index(IndexCourses).AddDocuments([]interface{}{doc})
	return err
}

// SearchTeachers searches the teachers index.
func (m *Meilisearch) SearchTeachers(query string, opts *meilisearch.SearchRequest) (*meilisearch.SearchResponse, error) {
	return m.Client.Index(IndexTeachers).Search(query, opts)
}

// SearchCourses searches the courses index.
func (m *Meilisearch) SearchCourses(query string, opts *meilisearch.SearchRequest) (*meilisearch.SearchResponse, error) {
	return m.Client.Index(IndexCourses).Search(query, opts)
}

// DeleteTeacher removes a teacher from the search index.
func (m *Meilisearch) DeleteTeacher(id string) error {
	_, err := m.Client.Index(IndexTeachers).DeleteDocument(id)
	return err
}

// DeleteCourse removes a course from the search index.
func (m *Meilisearch) DeleteCourse(id string) error {
	_, err := m.Client.Index(IndexCourses).DeleteDocument(id)
	return err
}
