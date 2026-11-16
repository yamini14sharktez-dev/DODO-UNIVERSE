package order

import (
	"context"
	"net/http"

	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/pkg/response"
	"github.com/google/uuid"
)

type Order struct {
	ID         uuid.UUID `json:"id"`
	CustomerID uuid.UUID `json:"customer_id"`
	ProviderID uuid.UUID `json:"provider_id"`
	Service    string    `json:"service"`
	Status     string    `json:"status"`
	Amount     float64   `json:"amount"`
}

type Service interface {
	ListCustomerOrders(ctx context.Context, customerID uuid.UUID) ([]Order, error)
	ListProviderIncomingOrders(ctx context.Context, providerID uuid.UUID) ([]Order, error)
}

type orderService struct{}

func NewService() Service {
	return &orderService{}
}

func (s *orderService) ListCustomerOrders(ctx context.Context, customerID uuid.UUID) ([]Order, error) {
	return []Order{}, nil
}

func (s *orderService) ListProviderIncomingOrders(ctx context.Context, providerID uuid.UUID) ([]Order, error) {
	return []Order{}, nil
}

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.Handle("GET /api/v1/orders/buying", authMiddleware(http.HandlerFunc(h.HandleGetCustomerOrders)))
	mux.Handle("GET /api/v1/orders/providing", authMiddleware(http.HandlerFunc(h.HandleGetProviderOrders)))
}

func (h *Handler) HandleGetCustomerOrders(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok {
		response.Unauthorized(w, "Unauthorized")
		return
	}
	uid, _ := uuid.Parse(claims.UserID)
	orders, err := h.service.ListCustomerOrders(r.Context(), uid)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, orders)
}

func (h *Handler) HandleGetProviderOrders(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok {
		response.Unauthorized(w, "Unauthorized")
		return
	}
	uid, _ := uuid.Parse(claims.UserID)
	orders, err := h.service.ListProviderIncomingOrders(r.Context(), uid)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, orders)
}

