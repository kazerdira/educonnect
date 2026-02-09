package storage

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"time"

	"educonnect/internal/config"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// MinIO wraps the MinIO client for S3-compatible storage.
type MinIO struct {
	Client *minio.Client
	cfg    config.MinIOConfig
}

// NewMinIO creates a new MinIO client and ensures buckets exist.
func NewMinIO(cfg config.MinIOConfig) (*MinIO, error) {
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("minio client: %w", err)
	}

	m := &MinIO{Client: client, cfg: cfg}

	// Ensure all required buckets exist
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	buckets := []string{
		cfg.BucketAvatars,
		cfg.BucketDocuments,
		cfg.BucketVideos,
		cfg.BucketRecordings,
	}

	for _, bucket := range buckets {
		if err := m.ensureBucket(ctx, bucket); err != nil {
			return nil, err
		}
	}

	return m, nil
}

// ensureBucket creates a bucket if it doesn't exist.
func (m *MinIO) ensureBucket(ctx context.Context, name string) error {
	exists, err := m.Client.BucketExists(ctx, name)
	if err != nil {
		return fmt.Errorf("check bucket %s: %w", name, err)
	}
	if !exists {
		if err := m.Client.MakeBucket(ctx, name, minio.MakeBucketOptions{}); err != nil {
			return fmt.Errorf("create bucket %s: %w", name, err)
		}
		slog.Info("created bucket", "name", name)
	}
	return nil
}

// Upload uploads a file to a bucket and returns the object key.
func (m *MinIO) Upload(ctx context.Context, bucket, key string, reader io.Reader, size int64, contentType string) error {
	_, err := m.Client.PutObject(ctx, bucket, key, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	return err
}

// Download retrieves a file from a bucket.
func (m *MinIO) Download(ctx context.Context, bucket, key string) (io.ReadCloser, error) {
	obj, err := m.Client.GetObject(ctx, bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, err
	}
	return obj, nil
}

// Delete removes a file from a bucket.
func (m *MinIO) Delete(ctx context.Context, bucket, key string) error {
	return m.Client.RemoveObject(ctx, bucket, key, minio.RemoveObjectOptions{})
}

// GetPresignedURL generates a temporary download URL.
func (m *MinIO) GetPresignedURL(ctx context.Context, bucket, key string, expiry time.Duration) (string, error) {
	url, err := m.Client.PresignedGetObject(ctx, bucket, key, expiry, nil)
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

// GetUploadPresignedURL generates a temporary upload URL.
func (m *MinIO) GetUploadPresignedURL(ctx context.Context, bucket, key string, expiry time.Duration) (string, error) {
	url, err := m.Client.PresignedPutObject(ctx, bucket, key, expiry)
	if err != nil {
		return "", err
	}
	return url.String(), nil
}

// ─── Bucket accessors ───────────────────────────────────────────

func (m *MinIO) BucketAvatars() string    { return m.cfg.BucketAvatars }
func (m *MinIO) BucketDocuments() string  { return m.cfg.BucketDocuments }
func (m *MinIO) BucketVideos() string     { return m.cfg.BucketVideos }
func (m *MinIO) BucketRecordings() string { return m.cfg.BucketRecordings }
