package servicemgmt

import (
	"context"
	"net/http"

	"dodo-universe-backend/pkg/response"
)

type ServiceCategory struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Subservices []string `json:"subservices"`
}

type Service interface {
	ListCategories(ctx context.Context) ([]ServiceCategory, error)
}

type serviceMgmt struct{}

func NewService() Service {
	return &serviceMgmt{}
}

func (s *serviceMgmt) ListCategories(ctx context.Context) ([]ServiceCategory, error) {
	return []ServiceCategory{
		{
			ID:          "cat_home_repairs",
			Name:        "Home Repairs",
			Description: "Electrical, plumbing, carpentry, and general repairs",
			Subservices: []string{"Electrician", "Plumber", "Carpenter"},
		},
		{
			ID:          "cat_cleaning",
			Name:        "Cleaning & Pest Control",
			Description: "Deep cleaning, sanitization, and pest management",
			Subservices: []string{"Home Deep Cleaning", "Kitchen Cleaning", "Pest Control"},
		},
	}, nil
}

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/services/categories", h.HandleListCategories)
}

func (h *Handler) HandleListCategories(w http.ResponseWriter, r *http.Request) {
	cats, err := h.service.ListCategories(r.Context())
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, cats)
}

