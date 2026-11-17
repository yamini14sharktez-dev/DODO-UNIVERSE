package admin

import (
	"context"
	"net/http"

	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/internal/models"
	"dodo-universe-backend/pkg/response"
)

type PlatformMetrics struct {
	TotalUsers     int `json:"total_users"`
	TotalProviders int `json:"total_providers"`
	TotalOrders    int `json:"total_orders"`
}

type Service interface {
	GetMetrics(ctx context.Context) (*PlatformMetrics, error)
}

type adminService struct{}

func NewService() Service {
	return &adminService{}
}

func (s *adminService) GetMetrics(ctx context.Context) (*PlatformMetrics, error) {
	return &PlatformMetrics{
		TotalUsers:     1,
		TotalProviders: 0,
		TotalOrders:    0,
	}, nil
}

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.Handle("GET /api/v1/admin/metrics", authMiddleware(http.HandlerFunc(h.HandleGetMetrics)))
}

func (h *Handler) HandleGetMetrics(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok || claims.Role != models.RoleAdmin {
		response.Forbidden(w, "Admin access required")
		return
	}
	metrics, err := h.service.GetMetrics(r.Context())
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, metrics)
}

