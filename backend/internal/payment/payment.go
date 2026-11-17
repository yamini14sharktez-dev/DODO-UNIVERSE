package payment

import (
	"context"
	"net/http"

	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/pkg/response"
	"github.com/google/uuid"
)

type WalletBalance struct {
	UserID    uuid.UUID `json:"user_id"`
	Available float64   `json:"available"`
	Pending   float64   `json:"pending"`
	Currency  string    `json:"currency"`
}

type Service interface {
	GetWallet(ctx context.Context, userID uuid.UUID) (*WalletBalance, error)
}

type paymentService struct{}

func NewService() Service {
	return &paymentService{}
}

func (s *paymentService) GetWallet(ctx context.Context, userID uuid.UUID) (*WalletBalance, error) {
	return &WalletBalance{
		UserID:    userID,
		Available: 0.0,
		Pending:   0.0,
		Currency:  "INR",
	}, nil
}

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.Handle("GET /api/v1/payments/wallet", authMiddleware(http.HandlerFunc(h.HandleGetWallet)))
}

func (h *Handler) HandleGetWallet(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok {
		response.Unauthorized(w, "Unauthorized")
		return
	}
	uid, _ := uuid.Parse(claims.UserID)
	wallet, err := h.service.GetWallet(r.Context(), uid)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, wallet)
}

