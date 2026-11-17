package database

import (
	"context"
	"strings"
	"sync"
	"time"

	"dodo-universe-backend/internal/models"
	"github.com/google/uuid"
)

type memoryAdminRepo struct {
	mu            sync.RWMutex
	admins        map[uuid.UUID]*models.AdminUser
	adminSessions map[uuid.UUID]*models.AdminSession
	auditLogs     []*models.AuditLog
	categories    map[uuid.UUID]*models.ServiceCategory
	forms         map[uuid.UUID]*models.FormDefinition
	vendorApps    map[uuid.UUID]*models.VendorApplication
	listings      map[uuid.UUID]*models.ProductListing
	orders        map[uuid.UUID]*models.AdminOrder
	requests      map[uuid.UUID]*models.QuotationRequest
	payments      map[uuid.UUID]*models.PaymentRecord
	commissions   map[uuid.UUID]*models.CommissionRule
	settings      map[string]interface{}
	store         *MemoryStore
}

var (
	globalMemAdminOnce sync.Once
	globalMemAdmin     *memoryAdminRepo
)

func (m *MemoryStore) Admin() AdminRepository {
	globalMemAdminOnce.Do(func() {
		globalMemAdmin = &memoryAdminRepo{
			admins:        make(map[uuid.UUID]*models.AdminUser),
			adminSessions: make(map[uuid.UUID]*models.AdminSession),
			auditLogs:     make([]*models.AuditLog, 0),
			categories:    make(map[uuid.UUID]*models.ServiceCategory),
			forms:         make(map[uuid.UUID]*models.FormDefinition),
			vendorApps:    make(map[uuid.UUID]*models.VendorApplication),
			listings:      make(map[uuid.UUID]*models.ProductListing),
			orders:        make(map[uuid.UUID]*models.AdminOrder),
			requests:      make(map[uuid.UUID]*models.QuotationRequest),
			payments:      make(map[uuid.UUID]*models.PaymentRecord),
			commissions:   make(map[uuid.UUID]*models.CommissionRule),
			settings: map[string]interface{}{
				"platform_maintenance_mode": map[string]interface{}{"enabled": false, "message": "Scheduled maintenance in progress"},
				"default_commission_rate":   map[string]interface{}{"percent": 10.0, "fixed_fee": 0.0},
				"allowed_upload_formats":    map[string]interface{}{"images": []string{"jpg", "jpeg", "png", "webp"}, "documents": []string{"pdf", "doc", "docx"}},
			},
			store: m,
		}
	})
	return globalMemAdmin
}

func (r *memoryAdminRepo) FindAdminByID(ctx context.Context, id uuid.UUID) (*models.AdminUser, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	a, ok := r.admins[id]
	if !ok {
		return nil, ErrNotFound
	}
	return a, nil
}

func (r *memoryAdminRepo) FindAdminByEmailOrPhone(ctx context.Context, identifier string) (*models.AdminUser, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	norm := strings.TrimSpace(strings.ToLower(identifier))
	for _, a := range r.admins {
		if strings.ToLower(a.Email) == norm || a.Phone == identifier {
			return a, nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryAdminRepo) CreateAdmin(ctx context.Context, admin *models.AdminUser) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if admin.ID == uuid.Nil {
		admin.ID = uuid.New()
	}
	now := time.Now().UTC()
	admin.CreatedAt = now
	admin.UpdatedAt = now
	r.admins[admin.ID] = admin
	return nil
}

func (r *memoryAdminRepo) UpdateAdmin(ctx context.Context, admin *models.AdminUser) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	admin.UpdatedAt = time.Now().UTC()
	r.admins[admin.ID] = admin
	return nil
}

func (r *memoryAdminRepo) ListAdmins(ctx context.Context) ([]*models.AdminUser, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.AdminUser
	for _, a := range r.admins {
		list = append(list, a)
	}
	return list, nil
}

func (r *memoryAdminRepo) RecordAdminFailedLogin(ctx context.Context, id uuid.UUID, lockUntil *time.Time) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if a, ok := r.admins[id]; ok {
		a.FailedLoginAttempts++
		a.LockedUntil = lockUntil
		a.UpdatedAt = time.Now().UTC()
	}
	return nil
}

func (r *memoryAdminRepo) ResetAdminFailedLogins(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if a, ok := r.admins[id]; ok {
		a.FailedLoginAttempts = 0
		a.LockedUntil = nil
		now := time.Now().UTC()
		a.LastLoginAt = &now
		a.UpdatedAt = now
	}
	return nil
}

func (r *memoryAdminRepo) CreateAdminSession(ctx context.Context, session *models.AdminSession) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.adminSessions[session.ID] = session
	return nil
}

func (r *memoryAdminRepo) FindAdminSessionByTokenHash(ctx context.Context, tokenHash string) (*models.AdminSession, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, s := range r.adminSessions {
		if s.TokenHash == tokenHash {
			if s.RevokedAt != nil || time.Now().UTC().After(s.ExpiresAt) {
				return nil, ErrSessionAlreadyRevoked
			}
			return s, nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryAdminRepo) RevokeAdminSession(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if s, ok := r.adminSessions[id]; ok {
		now := time.Now().UTC()
		s.RevokedAt = &now
	}
	return nil
}

func (r *memoryAdminRepo) GetDashboardMetrics(ctx context.Context) (*models.AdminDashboardMetrics, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var activeV, pendV, pendOrd, compOrd, cancOrd int64
	for _, va := range r.vendorApps {
		if va.Status == "approved" {
			activeV++
		} else if va.Status == "pending" {
			pendV++
		}
	}
	for _, o := range r.orders {
		if o.Status == "pending" {
			pendOrd++
		} else if o.Status == "completed" {
			compOrd++
		} else if o.Status == "cancelled" {
			cancOrd++
		}
	}

	return &models.AdminDashboardMetrics{
		TotalPeople:               int64(len(r.store.users)),
		ActiveVendors:             activeV,
		PendingVendorApplications: pendV,
		TotalServices:             int64(len(r.categories)),
		TotalCategories:           int64(len(r.categories)),
		TotalListings:             int64(len(r.listings)),
		TotalOrders:               int64(len(r.orders)),
		PendingOrders:             pendOrd,
		CompletedOrders:           compOrd,
		CancelledOrders:           cancOrd,
		PendingQuoteRequests:      int64(len(r.requests)),
		TotalPaymentVolume:        0,
		RecentActivity:            r.auditLogs,
	}, nil
}

func (r *memoryAdminRepo) ListPeople(ctx context.Context, search string, limit, offset int) ([]*models.User, int64, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()
	var list []*models.User
	for _, u := range r.store.users {
		if search == "" || strings.Contains(strings.ToLower(u.FullName), strings.ToLower(search)) || strings.Contains(u.Phone, search) {
			list = append(list, u)
		}
	}
	total := int64(len(list))
	if offset > len(list) {
		return []*models.User{}, total, nil
	}
	end := offset + limit
	if end > len(list) {
		end = len(list)
	}
	return list[offset:end], total, nil
}

func (r *memoryAdminRepo) GetPersonDetails(ctx context.Context, id uuid.UUID) (*models.User, []*models.AdminOrder, []*models.VendorApplication, []*models.ProductListing, error) {
	u, err := r.store.Users().FindByID(ctx, id)
	if err != nil {
		return nil, nil, nil, nil, err
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	var orders []*models.AdminOrder
	for _, o := range r.orders {
		if o.CustomerID == id || o.VendorID == id {
			orders = append(orders, o)
		}
	}
	var apps []*models.VendorApplication
	for _, a := range r.vendorApps {
		if a.UserID == id {
			apps = append(apps, a)
		}
	}
	var listings []*models.ProductListing
	for _, l := range r.listings {
		if l.VendorID == id {
			listings = append(listings, l)
		}
	}
	return u, orders, apps, listings, nil
}

func (r *memoryAdminRepo) SetPersonStatus(ctx context.Context, id uuid.UUID, isSuspended bool) error {
	u, err := r.store.Users().FindByID(ctx, id)
	if err != nil {
		return err
	}
	if isSuspended {
		u.Role = "suspended"
	} else {
		u.Role = models.RoleUser
	}
	return r.store.Users().Update(ctx, u)
}

func (r *memoryAdminRepo) ListVendorApplications(ctx context.Context, status string, limit, offset int) ([]*models.VendorApplication, int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.VendorApplication
	for _, a := range r.vendorApps {
		if status == "" || a.Status == status {
			list = append(list, a)
		}
	}
	total := int64(len(list))
	if offset > len(list) {
		return []*models.VendorApplication{}, total, nil
	}
	end := offset + limit
	if end > len(list) {
		end = len(list)
	}
	return list[offset:end], total, nil
}

func (r *memoryAdminRepo) GetVendorApplication(ctx context.Context, id uuid.UUID) (*models.VendorApplication, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	a, ok := r.vendorApps[id]
	if !ok {
		return nil, ErrNotFound
	}
	return a, nil
}

func (r *memoryAdminRepo) UpdateVendorApplication(ctx context.Context, app *models.VendorApplication) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	app.UpdatedAt = time.Now().UTC()
	r.vendorApps[app.ID] = app
	return nil
}

func (r *memoryAdminRepo) ListCategories(ctx context.Context) ([]*models.ServiceCategory, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.ServiceCategory
	for _, c := range r.categories {
		list = append(list, c)
	}
	return list, nil
}

func (r *memoryAdminRepo) CreateCategory(ctx context.Context, cat *models.ServiceCategory) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if cat.ID == uuid.Nil {
		cat.ID = uuid.New()
	}
	now := time.Now().UTC()
	cat.CreatedAt = now
	cat.UpdatedAt = now
	r.categories[cat.ID] = cat
	return nil
}

func (r *memoryAdminRepo) UpdateCategory(ctx context.Context, cat *models.ServiceCategory) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	cat.UpdatedAt = time.Now().UTC()
	r.categories[cat.ID] = cat
	return nil
}

func (r *memoryAdminRepo) DeleteCategory(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.categories, id)
	return nil
}

func (r *memoryAdminRepo) GetFormDefinition(ctx context.Context, categoryID uuid.UUID) (*models.FormDefinition, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, f := range r.forms {
		if f.CategoryID == categoryID {
			return f, nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryAdminRepo) SaveFormDefinition(ctx context.Context, form *models.FormDefinition) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if form.ID == uuid.Nil {
		form.ID = uuid.New()
	}
	now := time.Now().UTC()
	form.CreatedAt = now
	form.UpdatedAt = now
	r.forms[form.ID] = form
	return nil
}

func (r *memoryAdminRepo) ListListings(ctx context.Context, status string, limit, offset int) ([]*models.ProductListing, int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.ProductListing
	for _, l := range r.listings {
		if status == "" || l.ApprovalStatus == status {
			list = append(list, l)
		}
	}
	total := int64(len(list))
	if offset > len(list) {
		return []*models.ProductListing{}, total, nil
	}
	end := offset + limit
	if end > len(list) {
		end = len(list)
	}
	return list[offset:end], total, nil
}

func (r *memoryAdminRepo) UpdateListingApproval(ctx context.Context, id uuid.UUID, status string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if l, ok := r.listings[id]; ok {
		l.ApprovalStatus = status
		l.UpdatedAt = time.Now().UTC()
	}
	return nil
}

func (r *memoryAdminRepo) UpdateListingActiveStatus(ctx context.Context, id uuid.UUID, isActive bool) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if l, ok := r.listings[id]; ok {
		l.IsActive = isActive
		l.UpdatedAt = time.Now().UTC()
	}
	return nil
}

func (r *memoryAdminRepo) ListOrders(ctx context.Context, status string, search string, limit, offset int) ([]*models.AdminOrder, int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.AdminOrder
	for _, o := range r.orders {
		if status == "" || o.Status == status {
			list = append(list, o)
		}
	}
	total := int64(len(list))
	if offset > len(list) {
		return []*models.AdminOrder{}, total, nil
	}
	end := offset + limit
	if end > len(list) {
		end = len(list)
	}
	return list[offset:end], total, nil
}

func (r *memoryAdminRepo) GetOrder(ctx context.Context, id uuid.UUID) (*models.AdminOrder, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	o, ok := r.orders[id]
	if !ok {
		return nil, ErrNotFound
	}
	return o, nil
}

func (r *memoryAdminRepo) UpdateOrderDispute(ctx context.Context, id uuid.UUID, resolution string, adminID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if o, ok := r.orders[id]; ok {
		o.DisputeResolution = resolution
		o.ResolvedBy = &adminID
		now := time.Now().UTC()
		o.ResolvedAt = &now
		o.Status = "completed"
		o.UpdatedAt = now
	}
	return nil
}

func (r *memoryAdminRepo) ListQuotationRequests(ctx context.Context, status string, limit, offset int) ([]*models.QuotationRequest, int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.QuotationRequest
	for _, req := range r.requests {
		if status == "" || req.Status == status {
			list = append(list, req)
		}
	}
	total := int64(len(list))
	if offset > len(list) {
		return []*models.QuotationRequest{}, total, nil
	}
	end := offset + limit
	if end > len(list) {
		end = len(list)
	}
	return list[offset:end], total, nil
}

func (r *memoryAdminRepo) GetQuotationRequest(ctx context.Context, id uuid.UUID) (*models.QuotationRequest, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	req, ok := r.requests[id]
	if !ok {
		return nil, ErrNotFound
	}
	return req, nil
}

func (r *memoryAdminRepo) ListPayments(ctx context.Context, paymentType, status string, limit, offset int) ([]*models.PaymentRecord, int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.PaymentRecord
	for _, p := range r.payments {
		if (paymentType == "" || p.PaymentType == paymentType) && (status == "" || p.Status == status) {
			list = append(list, p)
		}
	}
	total := int64(len(list))
	if offset > len(list) {
		return []*models.PaymentRecord{}, total, nil
	}
	end := offset + limit
	if end > len(list) {
		end = len(list)
	}
	return list[offset:end], total, nil
}

func (r *memoryAdminRepo) ListCommissionRules(ctx context.Context) ([]*models.CommissionRule, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.CommissionRule
	for _, cr := range r.commissions {
		list = append(list, cr)
	}
	return list, nil
}

func (r *memoryAdminRepo) SetCommissionRule(ctx context.Context, rule *models.CommissionRule) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if rule.ID == uuid.Nil {
		rule.ID = uuid.New()
	}
	now := time.Now().UTC()
	rule.CreatedAt = now
	rule.UpdatedAt = now
	r.commissions[rule.ID] = rule
	return nil
}

func (r *memoryAdminRepo) CreateAuditLog(ctx context.Context, log *models.AuditLog) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if log.ID == uuid.Nil {
		log.ID = uuid.New()
	}
	log.CreatedAt = time.Now().UTC()
	r.auditLogs = append([]*models.AuditLog{log}, r.auditLogs...)
	return nil
}

func (r *memoryAdminRepo) ListAuditLogs(ctx context.Context, entityType, action string, limit, offset int) ([]*models.AuditLog, int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var list []*models.AuditLog
	for _, l := range r.auditLogs {
		if (entityType == "" || l.EntityType == entityType) && (action == "" || l.Action == action) {
			list = append(list, l)
		}
	}
	total := int64(len(list))
	if offset > len(list) {
		return []*models.AuditLog{}, total, nil
	}
	end := offset + limit
	if end > len(list) {
		end = len(list)
	}
	return list[offset:end], total, nil
}

func (r *memoryAdminRepo) GetSettings(ctx context.Context) (map[string]interface{}, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	res := make(map[string]interface{})
	for k, v := range r.settings {
		res[k] = v
	}
	return res, nil
}

func (r *memoryAdminRepo) UpdateSetting(ctx context.Context, key string, val interface{}, adminID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.settings[key] = val
	return nil
}
