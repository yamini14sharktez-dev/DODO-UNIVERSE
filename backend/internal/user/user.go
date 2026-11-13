package user

import (
	"context"
	"net/http"

	"dodo-universe-backend/internal/database"
	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/internal/models"
	"dodo-universe-backend/pkg/response"
	"github.com/google/uuid"
)

// Service defines User business logic.
type Service interface {
	GetProfile(ctx context.Context, userID uuid.UUID) (*models.User, error)
	UpdateProfile(ctx context.Context, userID uuid.UUID, fullName string) (*models.User, error)
}

type userService struct {
	store database.Store
}

// NewService creates a new User Service.
func NewService(store database.Store) Service {
	return &userService{store: store}
}

func (s *userService) GetProfile(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	return s.store.Users().FindByID(ctx, userID)
}

func (s *userService) UpdateProfile(ctx context.Context, userID uuid.UUID, fullName string) (*models.User, error) {
	u, err := s.store.Users().FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	u.FullName = fullName
	if err := s.store.Users().Update(ctx, u); err != nil {
		return nil, err
	}
	return u, nil
}

// Handler provides HTTP endpoints for User Service.
type Handler struct {
	service Service
}

// NewHandler creates a User HTTP handler.
func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers User routes onto the servemux.
func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.Handle("GET /api/v1/users/profile", authMiddleware(http.HandlerFunc(h.HandleGetProfile)))
}

func (h *Handler) HandleGetProfile(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok {
		response.Unauthorized(w, "Unauthorized")
		return
	}
	uid, _ := uuid.Parse(claims.UserID)
	profile, err := h.service.GetProfile(r.Context(), uid)
	if err != nil {
		response.NotFound(w, "Profile not found")
		return
	}
	response.OK(w, profile)
}

