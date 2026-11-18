package admin

import (
	"encoding/json"
	"net/http"
	"strconv"

	"dodo-universe-backend/internal/models"
	"dodo-universe-backend/pkg/response"
	"github.com/google/uuid"
)

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux, adminAuth func(http.Handler) http.Handler) {
	// Public auth endpoints
	mux.HandleFunc("POST /api/v1/admin/auth/login", h.HandleLogin)
	mux.HandleFunc("POST /api/v1/admin/auth/refresh", h.HandleRefresh)
	mux.HandleFunc("POST /api/v1/admin/auth/logout", h.HandleLogout)

	// Admin protected endpoints
	superOnly := RequireRole(models.AdminRoleSuper)

	// Auth profile
	mux.Handle("GET /api/v1/admin/auth/me", adminAuth(http.HandlerFunc(h.HandleGetMe)))

	// Dashboard metrics
	mux.Handle("GET /api/v1/admin/dashboard/metrics", adminAuth(http.HandlerFunc(h.HandleGetDashboardMetrics)))

	// People Management
	mux.Handle("GET /api/v1/admin/people", adminAuth(http.HandlerFunc(h.HandleListPeople)))
	mux.Handle("GET /api/v1/admin/people/{id}", adminAuth(http.HandlerFunc(h.HandleGetPersonDetails)))
	mux.Handle("PATCH /api/v1/admin/people/{id}/status", adminAuth(http.HandlerFunc(h.HandleSetPersonStatus)))

	// Vendor Applications
	mux.Handle("GET /api/v1/admin/vendor-applications", adminAuth(http.HandlerFunc(h.HandleListVendorApplications)))
	mux.Handle("GET /api/v1/admin/vendor-applications/{id}", adminAuth(http.HandlerFunc(h.HandleGetVendorApplication)))
	mux.Handle("POST /api/v1/admin/vendor-applications/{id}/approve", adminAuth(http.HandlerFunc(h.HandleApproveVendorApplication)))
	mux.Handle("POST /api/v1/admin/vendor-applications/{id}/reject", adminAuth(http.HandlerFunc(h.HandleRejectVendorApplication)))
	mux.Handle("POST /api/v1/admin/vendor-applications/{id}/request-info", adminAuth(http.HandlerFunc(h.HandleRequestInfoVendorApplication)))

	// Services & Categories
	mux.Handle("GET /api/v1/admin/categories", adminAuth(http.HandlerFunc(h.HandleListCategories)))
	mux.Handle("POST /api/v1/admin/categories", adminAuth(http.HandlerFunc(h.HandleCreateCategory)))
	mux.Handle("PUT /api/v1/admin/categories/{id}", adminAuth(http.HandlerFunc(h.HandleUpdateCategory)))
	mux.Handle("DELETE /api/v1/admin/categories/{id}", adminAuth(http.HandlerFunc(h.HandleDeleteCategory)))

	// Dynamic Form Builder
	mux.Handle("GET /api/v1/admin/forms/{categoryId}", adminAuth(http.HandlerFunc(h.HandleGetFormDefinition)))
	mux.Handle("POST /api/v1/admin/forms/{categoryId}", adminAuth(http.HandlerFunc(h.HandleSaveFormDefinition)))

	// Products & Listings
	mux.Handle("GET /api/v1/admin/listings", adminAuth(http.HandlerFunc(h.HandleListListings)))
	mux.Handle("PATCH /api/v1/admin/listings/{id}/approval", adminAuth(http.HandlerFunc(h.HandleUpdateListingApproval)))
	mux.Handle("PATCH /api/v1/admin/listings/{id}/status", adminAuth(http.HandlerFunc(h.HandleUpdateListingStatus)))

	// Bookings & Orders
	mux.Handle("GET /api/v1/admin/orders", adminAuth(http.HandlerFunc(h.HandleListOrders)))
	mux.Handle("GET /api/v1/admin/orders/{id}", adminAuth(http.HandlerFunc(h.HandleGetOrder)))
	mux.Handle("PATCH /api/v1/admin/orders/{id}/dispute", adminAuth(http.HandlerFunc(h.HandleResolveOrderDispute)))

	// Requests & Quotations
	mux.Handle("GET /api/v1/admin/quotes/requests", adminAuth(http.HandlerFunc(h.HandleListQuotationRequests)))
	mux.Handle("GET /api/v1/admin/quotes/requests/{id}", adminAuth(http.HandlerFunc(h.HandleGetQuotationRequest)))

	// Payments & Commission
	mux.Handle("GET /api/v1/admin/finance/transactions", adminAuth(http.HandlerFunc(h.HandleListPayments)))
	mux.Handle("GET /api/v1/admin/finance/commissions", adminAuth(http.HandlerFunc(h.HandleListCommissionRules)))
	mux.Handle("PUT /api/v1/admin/finance/commissions", adminAuth(http.HandlerFunc(h.HandleSetCommissionRule)))

	// Admin Management (Super Admin only)
	mux.Handle("GET /api/v1/admin/admins", adminAuth(superOnly(http.HandlerFunc(h.HandleListAdmins))))
	mux.Handle("POST /api/v1/admin/admins", adminAuth(superOnly(http.HandlerFunc(h.HandleCreateAdmin))))
	mux.Handle("PATCH /api/v1/admin/admins/{id}", adminAuth(superOnly(http.HandlerFunc(h.HandleUpdateAdmin))))

	// Audit Logs
	mux.Handle("GET /api/v1/admin/audit-logs", adminAuth(http.HandlerFunc(h.HandleListAuditLogs)))

	// Settings
	mux.Handle("GET /api/v1/admin/settings", adminAuth(http.HandlerFunc(h.HandleGetSettings)))
	mux.Handle("PUT /api/v1/admin/settings", adminAuth(http.HandlerFunc(h.HandleUpdateSetting)))
}

// -----------------------------------------------------------------------------
// Auth Handlers
// -----------------------------------------------------------------------------

type loginReq struct {
	Identifier string `json:"identifier"`
	Password   string `json:"password"`
}

func (h *Handler) HandleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	res, err := h.service.Login(r.Context(), req.Identifier, req.Password, r.RemoteAddr)
	if err != nil {
		switch err {
		case ErrInvalidCredentials:
			response.Unauthorized(w, "Invalid email/phone or password")
		case ErrAdminLocked:
			response.Error(w, http.StatusTooManyRequests, "ACCOUNT_LOCKED", "Account locked for 15 minutes due to too many failed attempts")
		case ErrAdminInactive:
			response.Forbidden(w, "Admin account is deactivated")
		default:
			response.InternalServerError(w, err.Error())
		}
		return
	}
	response.OK(w, res)
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) HandleRefresh(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	tokens, err := h.service.RefreshToken(r.Context(), req.RefreshToken)
	if err != nil {
		response.Unauthorized(w, "Invalid or expired refresh token")
		return
	}
	response.OK(w, tokens)
}

func (h *Handler) HandleLogout(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.RefreshToken != "" {
		_ = h.service.Logout(r.Context(), req.RefreshToken)
	}
	response.OK(w, map[string]string{"message": "Logged out successfully"})
}

func (h *Handler) HandleGetMe(w http.ResponseWriter, r *http.Request) {
	claims, ok := GetAdminClaims(r)
	if !ok {
		response.Unauthorized(w, "Unauthorized")
		return
	}
	uid, _ := uuid.Parse(claims.AdminID)
	admin, err := h.service.GetAdminProfile(r.Context(), uid)
	if err != nil {
		response.NotFound(w, "Admin not found")
		return
	}
	response.OK(w, admin)
}

// -----------------------------------------------------------------------------
// Dashboard Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleGetDashboardMetrics(w http.ResponseWriter, r *http.Request) {
	metrics, err := h.service.GetMetrics(r.Context())
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, metrics)
}

// -----------------------------------------------------------------------------
// People Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleListPeople(w http.ResponseWriter, r *http.Request) {
	search := r.URL.Query().Get("search")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	users, total, err := h.service.ListPeople(r.Context(), search, limit, offset)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]interface{}{
		"items": users,
		"total": total,
	})
}

func (h *Handler) HandleGetPersonDetails(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	user, orders, apps, listings, err := h.service.GetPersonDetails(r.Context(), id)
	if err != nil {
		response.NotFound(w, "User not found")
		return
	}
	response.OK(w, map[string]interface{}{
		"user":         user,
		"orders":       orders,
		"applications": apps,
		"listings":     listings,
	})
}

type statusReq struct {
	Suspended bool `json:"suspended"`
}

func (h *Handler) HandleSetPersonStatus(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	var req statusReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	claims, _ := GetAdminClaims(r)
	if err := h.service.SetPersonStatus(r.Context(), id, req.Suspended, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "User status updated successfully"})
}

// -----------------------------------------------------------------------------
// Vendor Applications Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleListVendorApplications(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	apps, total, err := h.service.ListVendorApplications(r.Context(), status, limit, offset)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]interface{}{
		"items": apps,
		"total": total,
	})
}

func (h *Handler) HandleGetVendorApplication(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	app, err := h.service.GetVendorApplication(r.Context(), id)
	if err != nil {
		response.NotFound(w, "Application not found")
		return
	}
	response.OK(w, app)
}

func (h *Handler) HandleApproveVendorApplication(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	claims, _ := GetAdminClaims(r)
	if err := h.service.ApproveVendorApplication(r.Context(), id, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Application approved successfully"})
}

type rejectReq struct {
	Reason string `json:"reason"`
}

func (h *Handler) HandleRejectVendorApplication(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	var req rejectReq
	_ = json.NewDecoder(r.Body).Decode(&req)
	claims, _ := GetAdminClaims(r)
	if err := h.service.RejectVendorApplication(r.Context(), id, req.Reason, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Application rejected successfully"})
}

type infoReq struct {
	Notes string `json:"notes"`
}

func (h *Handler) HandleRequestInfoVendorApplication(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	var req infoReq
	_ = json.NewDecoder(r.Body).Decode(&req)
	claims, _ := GetAdminClaims(r)
	if err := h.service.RequestInfoVendorApplication(r.Context(), id, req.Notes, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Information requested successfully"})
}

// -----------------------------------------------------------------------------
// Categories Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleListCategories(w http.ResponseWriter, r *http.Request) {
	tree, err := h.service.ListCategoriesTree(r.Context())
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, tree)
}

func (h *Handler) HandleCreateCategory(w http.ResponseWriter, r *http.Request) {
	var cat models.ServiceCategory
	if err := json.NewDecoder(r.Body).Decode(&cat); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	claims, _ := GetAdminClaims(r)
	res, err := h.service.CreateCategory(r.Context(), &cat, claims, r.RemoteAddr)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.Created(w, res)
}

func (h *Handler) HandleUpdateCategory(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	var cat models.ServiceCategory
	if err := json.NewDecoder(r.Body).Decode(&cat); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	cat.ID = id
	claims, _ := GetAdminClaims(r)
	res, err := h.service.UpdateCategory(r.Context(), &cat, claims, r.RemoteAddr)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, res)
}

func (h *Handler) HandleDeleteCategory(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	claims, _ := GetAdminClaims(r)
	if err := h.service.DeleteCategory(r.Context(), id, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Category deleted successfully"})
}

// -----------------------------------------------------------------------------
// Dynamic Form Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleGetFormDefinition(w http.ResponseWriter, r *http.Request) {
	catID, err := uuid.Parse(r.PathValue("categoryId"))
	if err != nil {
		response.BadRequest(w, "Invalid category UUID")
		return
	}
	form, err := h.service.GetFormDefinition(r.Context(), catID)
	if err != nil {
		response.NotFound(w, "No form definition found for category")
		return
	}
	response.OK(w, form)
}

func (h *Handler) HandleSaveFormDefinition(w http.ResponseWriter, r *http.Request) {
	catID, err := uuid.Parse(r.PathValue("categoryId"))
	if err != nil {
		response.BadRequest(w, "Invalid category UUID")
		return
	}
	var form models.FormDefinition
	if err := json.NewDecoder(r.Body).Decode(&form); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	form.CategoryID = catID
	claims, _ := GetAdminClaims(r)
	res, err := h.service.SaveFormDefinition(r.Context(), &form, claims, r.RemoteAddr)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, res)
}

// -----------------------------------------------------------------------------
// Listings Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleListListings(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	listings, total, err := h.service.ListListings(r.Context(), status, limit, offset)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]interface{}{
		"items": listings,
		"total": total,
	})
}

type approvalReq struct {
	Approval string `json:"approval"`
}

func (h *Handler) HandleUpdateListingApproval(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	var req approvalReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	claims, _ := GetAdminClaims(r)
	if err := h.service.UpdateListingApproval(r.Context(), id, req.Approval, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Listing approval updated"})
}

type activeReq struct {
	Active bool `json:"active"`
}

func (h *Handler) HandleUpdateListingStatus(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	var req activeReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	claims, _ := GetAdminClaims(r)
	if err := h.service.UpdateListingStatus(r.Context(), id, req.Active, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Listing active status updated"})
}

// -----------------------------------------------------------------------------
// Orders Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleListOrders(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	search := r.URL.Query().Get("search")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	orders, total, err := h.service.ListOrders(r.Context(), status, search, limit, offset)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]interface{}{
		"items": orders,
		"total": total,
	})
}

func (h *Handler) HandleGetOrder(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	order, err := h.service.GetOrder(r.Context(), id)
	if err != nil {
		response.NotFound(w, "Order not found")
		return
	}
	response.OK(w, order)
}

type disputeReq struct {
	Resolution string `json:"resolution"`
}

func (h *Handler) HandleResolveOrderDispute(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	var req disputeReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	claims, _ := GetAdminClaims(r)
	if err := h.service.ResolveOrderDispute(r.Context(), id, req.Resolution, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Dispute resolved successfully"})
}

// -----------------------------------------------------------------------------
// Requests & Quotations Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleListQuotationRequests(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	reqs, total, err := h.service.ListQuotationRequests(r.Context(), status, limit, offset)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]interface{}{
		"items": reqs,
		"total": total,
	})
}

func (h *Handler) HandleGetQuotationRequest(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	req, err := h.service.GetQuotationRequest(r.Context(), id)
	if err != nil {
		response.NotFound(w, "Quotation request not found")
		return
	}
	response.OK(w, req)
}

// -----------------------------------------------------------------------------
// Payments & Commission Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleListPayments(w http.ResponseWriter, r *http.Request) {
	paymentType := r.URL.Query().Get("type")
	status := r.URL.Query().Get("status")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	payments, total, err := h.service.ListPayments(r.Context(), paymentType, status, limit, offset)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]interface{}{
		"items": payments,
		"total": total,
	})
}

func (h *Handler) HandleListCommissionRules(w http.ResponseWriter, r *http.Request) {
	rules, err := h.service.ListCommissionRules(r.Context())
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, rules)
}

func (h *Handler) HandleSetCommissionRule(w http.ResponseWriter, r *http.Request) {
	var rule models.CommissionRule
	if err := json.NewDecoder(r.Body).Decode(&rule); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	claims, _ := GetAdminClaims(r)
	if err := h.service.SetCommissionRule(r.Context(), &rule, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Commission rule configured"})
}

// -----------------------------------------------------------------------------
// Admin Management Handlers (Super Admin only)
// -----------------------------------------------------------------------------

func (h *Handler) HandleListAdmins(w http.ResponseWriter, r *http.Request) {
	admins, err := h.service.ListAdmins(r.Context())
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, admins)
}

type createAdminReq struct {
	Email    string           `json:"email"`
	Phone    string           `json:"phone"`
	FullName string           `json:"full_name"`
	Password string           `json:"password"`
	Role     models.AdminRole `json:"role"`
}

func (h *Handler) HandleCreateAdmin(w http.ResponseWriter, r *http.Request) {
	var req createAdminReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	if req.Role == "" {
		req.Role = models.AdminRoleOperations
	}
	admin := &models.AdminUser{
		Email:    req.Email,
		Phone:    req.Phone,
		FullName: req.FullName,
		Role:     req.Role,
		IsActive: true,
	}
	claims, _ := GetAdminClaims(r)
	created, err := h.service.CreateAdmin(r.Context(), admin, req.Password, claims, r.RemoteAddr)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.Created(w, created)
}

func (h *Handler) HandleUpdateAdmin(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		response.BadRequest(w, "Invalid UUID")
		return
	}
	var admin models.AdminUser
	if err := json.NewDecoder(r.Body).Decode(&admin); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	admin.ID = id
	claims, _ := GetAdminClaims(r)
	updated, err := h.service.UpdateAdmin(r.Context(), &admin, claims, r.RemoteAddr)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, updated)
}

// -----------------------------------------------------------------------------
// Audit Logs Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleListAuditLogs(w http.ResponseWriter, r *http.Request) {
	entityType := r.URL.Query().Get("entity_type")
	action := r.URL.Query().Get("action")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	logs, total, err := h.service.ListAuditLogs(r.Context(), entityType, action, limit, offset)
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]interface{}{
		"items": logs,
		"total": total,
	})
}

// -----------------------------------------------------------------------------
// Settings Handlers
// -----------------------------------------------------------------------------

func (h *Handler) HandleGetSettings(w http.ResponseWriter, r *http.Request) {
	settings, err := h.service.GetSettings(r.Context())
	if err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, settings)
}

type settingReq struct {
	Key   string      `json:"key"`
	Value interface{} `json:"value"`
}

func (h *Handler) HandleUpdateSetting(w http.ResponseWriter, r *http.Request) {
	var req settingReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON payload")
		return
	}
	claims, _ := GetAdminClaims(r)
	if err := h.service.UpdateSetting(r.Context(), req.Key, req.Value, claims, r.RemoteAddr); err != nil {
		response.InternalServerError(w, err.Error())
		return
	}
	response.OK(w, map[string]string{"message": "Setting updated successfully"})
}
