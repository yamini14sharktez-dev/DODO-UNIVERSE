package requestquote

import (
	"context"
	"net/http"

	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/pkg/response"
	"github.com/google/uuid"
)

type CustomRequest struct {
	ID          uuid.UUID `json:"id"`
	CustomerID  uuid.UUID `json:"customer_id"`
	Description string    `json:"description"`
	Budget      float64   `json:"budget"`
	Status      string    `json:"status"`
}

type Service interface {
	ListCustomerRequests(ctx context.Context, customerID uuid.UUID) ([]CustomRequest, error)
}

type requestService struct{}

func NewService() Service {
	return &requestService{}
}

func (s *requestService) ListCustomerRequests(ctx context.Context, customerID uuid.UUID) ([]CustomRequest, error) {
	return []CustomRequest{}, nil
}

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.Handle("GET /api/v1/requests", authMiddleware(http.HandlerFunc(h.HandleListRequests)))
}

func (h *Handler) HandleListRequests(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok {
		response.Unauthorized(w, "Unauthorized")
		return
	}
	uid, _ := uuid.Parse(claims.UserID)
	reqs, err := h.service.ListCustomerRequests(r.Context(), uid)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, reqs)
}

