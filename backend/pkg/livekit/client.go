package livekit

import (
	"context"
	"fmt"
	"time"

	"educonnect/internal/config"

	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
	lksdk "github.com/livekit/server-sdk-go/v2"
)

// Client wraps the LiveKit server SDK.
type Client struct {
	roomClient *lksdk.RoomServiceClient
	apiKey     string
	apiSecret  string
	host       string
}

// NewClient creates a new LiveKit client.
func NewClient(cfg config.LiveKitConfig) *Client {
	roomClient := lksdk.NewRoomServiceClient(cfg.Host, cfg.APIKey, cfg.APISecret)

	return &Client{
		roomClient: roomClient,
		apiKey:     cfg.APIKey,
		apiSecret:  cfg.APISecret,
		host:       cfg.Host,
	}
}

// SessionType defines the kind of live session.
type SessionType string

const (
	SessionTypeOneOnOne SessionType = "one_on_one"
	SessionTypeGroup    SessionType = "group"
)

// CreateRoom creates a new LiveKit room for a session.
func (c *Client) CreateRoom(ctx context.Context, roomName string, sessionType SessionType, maxParticipants uint32) (*livekit.Room, error) {
	if maxParticipants == 0 {
		switch sessionType {
		case SessionTypeOneOnOne:
			maxParticipants = 2
		case SessionTypeGroup:
			maxParticipants = 30
		}
	}

	room, err := c.roomClient.CreateRoom(ctx, &livekit.CreateRoomRequest{
		Name:             roomName,
		MaxParticipants:  maxParticipants,
		EmptyTimeout:     300, // 5 minutes
		DepartureTimeout: 60,  // 1 minute after last participant leaves
	})
	if err != nil {
		return nil, fmt.Errorf("create room: %w", err)
	}

	return room, nil
}

// DeleteRoom removes a LiveKit room.
func (c *Client) DeleteRoom(ctx context.Context, roomName string) error {
	_, err := c.roomClient.DeleteRoom(ctx, &livekit.DeleteRoomRequest{
		Room: roomName,
	})
	return err
}

// GenerateToken creates a JWT token for a participant to join a room.
func (c *Client) GenerateToken(roomName, participantID, participantName string, isTeacher bool) (string, error) {
	at := auth.NewAccessToken(c.apiKey, c.apiSecret)

	grant := &auth.VideoGrant{
		Room:     roomName,
		RoomJoin: true,
	}

	// Teachers get full permissions
	if isTeacher {
		grant.RoomAdmin = true
		grant.CanPublish = boolPtr(true)
		grant.CanSubscribe = boolPtr(true)
		grant.CanPublishData = boolPtr(true)
	} else {
		// Students have limited permissions by default
		grant.CanPublish = boolPtr(true)
		grant.CanSubscribe = boolPtr(true)
		grant.CanPublishData = boolPtr(true)
	}

	at.AddGrant(grant).
		SetIdentity(participantID).
		SetName(participantName).
		SetValidFor(24 * time.Hour)

	return at.ToJWT()
}

// ListParticipants returns all participants in a room.
func (c *Client) ListParticipants(ctx context.Context, roomName string) ([]*livekit.ParticipantInfo, error) {
	resp, err := c.roomClient.ListParticipants(ctx, &livekit.ListParticipantsRequest{
		Room: roomName,
	})
	if err != nil {
		return nil, err
	}
	return resp.Participants, nil
}

// MuteParticipant mutes/unmutes a participant's track.
func (c *Client) MuteParticipant(ctx context.Context, roomName, participantID string, muted bool) error {
	_, err := c.roomClient.MutePublishedTrack(ctx, &livekit.MuteRoomTrackRequest{
		Room:     roomName,
		Identity: participantID,
		Muted:    muted,
	})
	return err
}

// RemoveParticipant kicks a participant from a room.
func (c *Client) RemoveParticipant(ctx context.Context, roomName, participantID string) error {
	_, err := c.roomClient.RemoveParticipant(ctx, &livekit.RoomParticipantIdentity{
		Room:     roomName,
		Identity: participantID,
	})
	return err
}

func boolPtr(b bool) *bool {
	return &b
}
