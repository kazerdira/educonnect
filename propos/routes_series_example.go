package server

// ═══════════════════════════════════════════════════════════════
// NEW ROUTES TO ADD TO routes.go (inside setupRoutes)
//
// Add these inside the `protected` group after existing session routes.
// Also update server.go to initialize the sessionseries handler.
// ═══════════════════════════════════════════════════════════════

/*

STEP 1: In server.go, add to imports:
    "educonnect/internal/sessionseries"

STEP 2: In server.go New() function, add:
    seriesService := sessionseries.NewService(deps.DB, deps.LiveKit)
    seriesHandler := sessionseries.NewHandler(seriesService)

STEP 3: Add `seriesHandler *sessionseries.Handler` to the Server struct

STEP 4: In routes.go, replace or augment session routes:
*/

// ── Session Series routes ───────────────────────────────────
// This replaces the old simple session create flow
func (s *Server) setupSeriesRoutes_EXAMPLE() {
	protected := s.router.Group("/api/v1")

	// ── Session Series (teacher creates series/single sessions) ──
	series := protected.Group("/sessions/series")
	{
		series.POST("", s.seriesHandler.CreateSeries)               // Create a series
		series.GET("", s.seriesHandler.ListSeries)                  // List teacher's series
		series.GET("/:id", s.seriesHandler.GetSeries)               // Get series details
		series.POST("/:id/sessions", s.seriesHandler.AddSessions)   // Add session dates
		series.POST("/:id/invite", s.seriesHandler.InviteStudents)  // Invite students
		series.DELETE("/:id/students/:studentId", s.seriesHandler.RemoveStudent) // Remove student
	}

	// ── Invitations (student/parent view) ────────────────────────
	invitations := protected.Group("/invitations")
	{
		invitations.GET("", s.seriesHandler.ListInvitations)            // My invitations
		invitations.PUT("/:id/accept", s.seriesHandler.AcceptInvitation)  // Accept
		invitations.PUT("/:id/decline", s.seriesHandler.DeclineInvitation) // Decline
	}

	// ── Platform Fees ────────────────────────────────────────────
	fees := protected.Group("/fees")
	{
		fees.GET("/pending", s.seriesHandler.ListPendingFees)       // My pending fees
		fees.POST("/:id/confirm", s.seriesHandler.ConfirmFeePayment) // Confirm BaridiMob payment
	}

	// ── Join Session (updated with access control) ───────────────
	// This replaces the old /sessions/:id/join
	sessions := protected.Group("/sessions")
	{
		sessions.POST("/:id/join", s.seriesHandler.JoinSession)
	}
}

/*
COMPLETE FLOW SUMMARY:

1. Teacher creates a series:
   POST /api/v1/sessions/series
   {
     "title": "Math 3AM - January",
     "session_type": "group",
     "duration_hours": 2,
     "min_students": 3,
     "max_students": 15
   }

2. Teacher adds session dates:
   POST /api/v1/sessions/series/{seriesId}/sessions
   {
     "sessions": [
       {"start_time": "2026-01-05T14:00:00Z", "end_time": "2026-01-05T16:00:00Z"},
       {"start_time": "2026-01-07T14:00:00Z", "end_time": "2026-01-07T16:00:00Z"},
       // ... 6 more
     ]
   }

3. Teacher invites students:
   POST /api/v1/sessions/series/{seriesId}/invite
   {"student_ids": ["uuid1", "uuid2", "uuid3"]}

4. Student/parent sees invitation:
   GET /api/v1/invitations?status=invited

5. Student/parent accepts:
   PUT /api/v1/invitations/{enrollmentId}/accept
   → Platform fee is calculated (50 DA × 2h × 8 sessions = 800 DA)
   → Fee record is created

6. Student/parent pays fee:
   GET /api/v1/fees/pending → sees 800 DA pending
   POST /api/v1/fees/{feeId}/confirm
   {"provider_ref": "BARIDIMOB-12345"}

7. Student joins session:
   POST /api/v1/sessions/{sessionId}/join
   → System checks: enrolled? fee paid? → returns LiveKit token

FOR INDIVIDUAL SESSIONS:
- Same flow, but fee_payer = "teacher"
- Teacher sees the fee in GET /api/v1/fees/pending
- Teacher pays the 120 DA/h fee
- Student joins for free (no fee check on student side)
*/
