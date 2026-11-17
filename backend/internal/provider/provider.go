package provider

import (
	"context"
	"net/http"

	"dodo-universe-backend/internal/database"
	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/pkg/response"
	"github.com/google/uuid"
)

type ProviderStatus string

const (
	StatusPending  ProviderStatus = "pending"
	StatusApproved ProviderStatus = "approved"
	StatusRejected ProviderStatus = "rejected"
)

// ProviderProfile represents a provider application and status.
type ProviderProfile struct {
	ID             uuid.UUID      `json:"id"`
	UserID         uuid.UUID      `json:"user_id"`
	BusinessName   string         `json:"business_name"`
	Services       []string       `json:"services"`
	Status         ProviderStatus `json:"status"`
	DocumentsCount int            `json:"documents_count"`
}

// Service defines provider operations.
type Service interface {
	GetProviderStatus(ctx context.Context, userID uuid.UUID) (*ProviderProfile, error)
	Apply(ctx context.Context, userID uuid.UUID, businessName string, services []string) (*ProviderProfile, error)
}

type providerService struct {
	store database.Store
}

func NewService(store database.Store) Service {
	return &providerService{store: store}
}

func (s *providerService) GetProviderStatus(ctx context.Context, userID uuid.UUID) (*ProviderProfile, error) {
	// Stub implementation ready for Phase 4 database table creation
	return &ProviderProfile{
		ID:           uuid.New(),
		UserID:       userID,
		BusinessName: "DODO Provider",
		Services:     []string{"Electrician", "Plumber"},
		Status:       StatusPending,
	}, nil
}

func (s *providerService) Apply(ctx context.Context, userID uuid.UUID, businessName string, services []string) (*ProviderProfile, error) {
	return &ProviderProfile{
		ID:           uuid.New(),
		UserID:       userID,
		BusinessName: businessName,
		Services:     services,
		Status:       StatusPending,
	}, nil
}

// Handler handles Provider HTTP requests.
type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.Handle("GET /api/v1/provider/status", authMiddleware(http.HandlerFunc(h.HandleGetStatus)))
}

func (h *Handler) HandleGetStatus(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok {
		response.Unauthorized(w, "Unauthorized")
		return
	}
	uid, _ := uuid.Parse(claims.UserID)
	status, err := h.service.GetProviderStatus(r.Context(), uid)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, status)
}

