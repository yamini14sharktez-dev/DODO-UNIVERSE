package notification

import (
	"context"
	"net/http"

	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/pkg/response"
	"github.com/google/uuid"
)

type Notification struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	Type      string    `json:"type"` // "order", "request", "provider"
	IsRead    bool      `json:"is_read"`
	CreatedAt string    `json:"created_at"`
}

type Service interface {
	ListNotifications(ctx context.Context, userID uuid.UUID) ([]Notification, error)
}

type notificationService struct{}

func NewService() Service {
	return &notificationService{}
}

func (s *notificationService) ListNotifications(ctx context.Context, userID uuid.UUID) ([]Notification, error) {
	return []Notification{}, nil
}

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.Handle("GET /api/v1/notifications", authMiddleware(http.HandlerFunc(h.HandleListNotifications)))
}

func (h *Handler) HandleListNotifications(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok {
		response.Unauthorized(w, "Unauthorized")
		return
	}
	uid, _ := uuid.Parse(claims.UserID)
	notifs, err := h.service.ListNotifications(r.Context(), uid)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, notifs)
}

