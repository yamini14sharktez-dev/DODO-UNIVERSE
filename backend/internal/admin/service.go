package admin

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"dodo-universe-backend/internal/database"
	"dodo-universe-backend/internal/models"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrAdminNotFound       = errors.New("admin account not found")
	ErrAdminLocked         = errors.New("admin account is locked due to too many failed attempts")
	ErrAdminInactive       = errors.New("admin account has been deactivated")
	ErrInvalidCredentials  = errors.New("invalid email/phone or password")
	ErrInvalidRefreshToken = errors.New("invalid or expired refresh token")
)

type Service interface {
	// Auth
	Login(ctx context.Context, identifier, password, ipAddress string) (*models.AdminAuthResponse, error)
	RefreshToken(ctx context.Context, refreshToken string) (*models.AuthTokens, error)
	Logout(ctx context.Context, refreshToken string) error
	GetAdminProfile(ctx context.Context, adminID uuid.UUID) (*models.AdminUser, error)

	// Dashboard
	GetMetrics(ctx context.Context) (*models.AdminDashboardMetrics, error)

	// People
	ListPeople(ctx context.Context, search string, limit, offset int) ([]*models.User, int64, error)
	GetPersonDetails(ctx context.Context, id uuid.UUID) (*models.User, []*models.AdminOrder, []*models.VendorApplication, []*models.ProductListing, error)
	SetPersonStatus(ctx context.Context, id uuid.UUID, isSuspended bool, actor *models.AdminClaims, ip string) error

	// Vendor Applications
	ListVendorApplications(ctx context.Context, status string, limit, offset int) ([]*models.VendorApplication, int64, error)
	GetVendorApplication(ctx context.Context, id uuid.UUID) (*models.VendorApplication, error)
	ApproveVendorApplication(ctx context.Context, id uuid.UUID, actor *models.AdminClaims, ip string) error
	RejectVendorApplication(ctx context.Context, id uuid.UUID, reason string, actor *models.AdminClaims, ip string) error
	RequestInfoVendorApplication(ctx context.Context, id uuid.UUID, notes string, actor *models.AdminClaims, ip string) error

	// Categories
	ListCategoriesTree(ctx context.Context) ([]*models.ServiceCategory, error)
	CreateCategory(ctx context.Context, cat *models.ServiceCategory, actor *models.AdminClaims, ip string) (*models.ServiceCategory, error)
	UpdateCategory(ctx context.Context, cat *models.ServiceCategory, actor *models.AdminClaims, ip string) (*models.ServiceCategory, error)
	DeleteCategory(ctx context.Context, id uuid.UUID, actor *models.AdminClaims, ip string) error

	// Form Builder
	GetFormDefinition(ctx context.Context, categoryID uuid.UUID) (*models.FormDefinition, error)
	SaveFormDefinition(ctx context.Context, form *models.FormDefinition, actor *models.AdminClaims, ip string) (*models.FormDefinition, error)

	// Listings
	ListListings(ctx context.Context, status string, limit, offset int) ([]*models.ProductListing, int64, error)
	UpdateListingApproval(ctx context.Context, id uuid.UUID, approvalStatus string, actor *models.AdminClaims, ip string) error
	UpdateListingStatus(ctx context.Context, id uuid.UUID, isActive bool, actor *models.AdminClaims, ip string) error

	// Orders
	ListOrders(ctx context.Context, status, search string, limit, offset int) ([]*models.AdminOrder, int64, error)
	GetOrder(ctx context.Context, id uuid.UUID) (*models.AdminOrder, error)
	ResolveOrderDispute(ctx context.Context, id uuid.UUID, resolution string, actor *models.AdminClaims, ip string) error

	// Requests & Quotes
	ListQuotationRequests(ctx context.Context, status string, limit, offset int) ([]*models.QuotationRequest, int64, error)
	GetQuotationRequest(ctx context.Context, id uuid.UUID) (*models.QuotationRequest, error)

	// Payments & Commission
	ListPayments(ctx context.Context, paymentType, status string, limit, offset int) ([]*models.PaymentRecord, int64, error)
	ListCommissionRules(ctx context.Context) ([]*models.CommissionRule, error)
	SetCommissionRule(ctx context.Context, rule *models.CommissionRule, actor *models.AdminClaims, ip string) error

	// Admin Management
	ListAdmins(ctx context.Context) ([]*models.AdminUser, error)
	CreateAdmin(ctx context.Context, admin *models.AdminUser, password string, actor *models.AdminClaims, ip string) (*models.AdminUser, error)
	UpdateAdmin(ctx context.Context, admin *models.AdminUser, actor *models.AdminClaims, ip string) (*models.AdminUser, error)

	// Audit Logs
	ListAuditLogs(ctx context.Context, entityType, action string, limit, offset int) ([]*models.AuditLog, int64, error)

	// Settings
	GetSettings(ctx context.Context) (map[string]interface{}, error)
	UpdateSetting(ctx context.Context, key string, val interface{}, actor *models.AdminClaims, ip string) error
}

type adminService struct {
	store             database.Store
	jwtSecret         []byte
	jwtExpiryMinutes  int
	refreshExpiryDays int
}

func NewService(store database.Store, jwtSecret string, jwtExpiryMinutes, refreshExpiryDays int) Service {
	if jwtExpiryMinutes <= 0 {
		jwtExpiryMinutes = 60
	}
	if refreshExpiryDays <= 0 {
		refreshExpiryDays = 30
	}
	return &adminService{
		store:             store,
		jwtSecret:         []byte(jwtSecret),
		jwtExpiryMinutes:  jwtExpiryMinutes,
		refreshExpiryDays: refreshExpiryDays,
	}
}

// -----------------------------------------------------------------------------
// Authentication Logic
// -----------------------------------------------------------------------------

func (s *adminService) Login(ctx context.Context, identifier, password, ipAddress string) (*models.AdminAuthResponse, error) {
	admin, err := s.store.Admin().FindAdminByEmailOrPhone(ctx, identifier)
	if err != nil {
		return nil, ErrInvalidCredentials
	}

	if !admin.IsActive {
		return nil, ErrAdminInactive
	}

	if admin.LockedUntil != nil && time.Now().UTC().Before(*admin.LockedUntil) {
		return nil, ErrAdminLocked
	}

	// Compare bcrypt password hash
	if err := bcrypt.CompareHashAndPassword([]byte(admin.PasswordHash), []byte(password)); err != nil {
		// Increment failed attempts
		lockoutThreshold := 5
		var lockUntil *time.Time
		if admin.FailedLoginAttempts+1 >= lockoutThreshold {
			t := time.Now().UTC().Add(15 * time.Minute)
			lockUntil = &t
		}
		_ = s.store.Admin().RecordAdminFailedLogin(ctx, admin.ID, lockUntil)
		return nil, ErrInvalidCredentials
	}

	// Reset failed attempts upon successful authentication
	_ = s.store.Admin().ResetAdminFailedLogins(ctx, admin.ID)

	// Generate tokens
	tokens, err := s.generateTokens(ctx, admin)
	if err != nil {
		return nil, err
	}

	// Audit log
	_ = s.logAction(ctx, admin.ID, admin.FullName, string(admin.Role), "LOGIN", "admin", admin.ID.String(), nil, nil, ipAddress)

	return &models.AdminAuthResponse{
		Admin:  admin,
		Tokens: tokens,
	}, nil
}

func (s *adminService) RefreshToken(ctx context.Context, refreshToken string) (*models.AuthTokens, error) {
	tokenHash := hashToken(refreshToken)
	session, err := s.store.Admin().FindAdminSessionByTokenHash(ctx, tokenHash)
	if err != nil {
		return nil, ErrInvalidRefreshToken
	}

	admin, err := s.store.Admin().FindAdminByID(ctx, session.AdminID)
	if err != nil || !admin.IsActive {
		return nil, ErrAdminInactive
	}

	// Revoke old session and issue new pair
	_ = s.store.Admin().RevokeAdminSession(ctx, session.ID)
	return s.generateTokens(ctx, admin)
}

func (s *adminService) Logout(ctx context.Context, refreshToken string) error {
	tokenHash := hashToken(refreshToken)
	session, err := s.store.Admin().FindAdminSessionByTokenHash(ctx, tokenHash)
	if err != nil {
		return nil
	}
	return s.store.Admin().RevokeAdminSession(ctx, session.ID)
}

func (s *adminService) GetAdminProfile(ctx context.Context, adminID uuid.UUID) (*models.AdminUser, error) {
	return s.store.Admin().FindAdminByID(ctx, adminID)
}

func (s *adminService) generateTokens(ctx context.Context, admin *models.AdminUser) (*models.AuthTokens, error) {
	now := time.Now().UTC()
	accessExpiry := now.Add(time.Duration(s.jwtExpiryMinutes) * time.Minute)

	claims := &models.AdminClaims{
		AdminID:  admin.ID.String(),
		Email:    admin.Email,
		Phone:    admin.Phone,
		FullName: admin.FullName,
		Role:     admin.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   admin.ID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(accessExpiry),
			Issuer:    "dodo-universe-admin-backend",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signedAccess, err := token.SignedString(s.jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("failed to sign admin access token: %w", err)
	}

	// Generate refresh token
	bytes := make([]byte, 32)
	_, _ = rand.Read(bytes)
	rawRefreshToken := hex.EncodeToString(bytes)
	tokenHash := hashToken(rawRefreshToken)

	session := &models.AdminSession{
		ID:        uuid.New(),
		AdminID:   admin.ID,
		TokenHash: tokenHash,
		ExpiresAt: now.AddDate(0, 0, s.refreshExpiryDays),
		CreatedAt: now,
	}

	if err := s.store.Admin().CreateAdminSession(ctx, session); err != nil {
		return nil, fmt.Errorf("failed to create admin session: %w", err)
	}

	return &models.AuthTokens{
		AccessToken:  signedAccess,
		RefreshToken: rawRefreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    int64(s.jwtExpiryMinutes * 60),
	}, nil
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

func (s *adminService) logAction(ctx context.Context, adminID uuid.UUID, adminName, adminRole, action, entityType, entityID string, oldVal, newVal interface{}, ip string) error {
	var oldBytes, newBytes []byte
	if oldVal != nil {
		oldBytes, _ = json.Marshal(oldVal)
	}
	if newVal != nil {
		newBytes, _ = json.Marshal(newVal)
	}

	return s.store.Admin().CreateAuditLog(ctx, &models.AuditLog{
		ID:         uuid.New(),
		AdminID:    &adminID,
		AdminName:  adminName,
		AdminRole:  adminRole,
		Action:     action,
		EntityType: entityType,
		EntityID:   entityID,
		OldValues:  oldBytes,
		NewValues:  newBytes,
		IPAddress:  ip,
		CreatedAt:  time.Now().UTC(),
	})
}

// -----------------------------------------------------------------------------
// Dashboard Metrics
// -----------------------------------------------------------------------------

func (s *adminService) GetMetrics(ctx context.Context) (*models.AdminDashboardMetrics, error) {
	return s.store.Admin().GetDashboardMetrics(ctx)
}

// -----------------------------------------------------------------------------
// People Management
// -----------------------------------------------------------------------------

func (s *adminService) ListPeople(ctx context.Context, search string, limit, offset int) ([]*models.User, int64, error) {
	return s.store.Admin().ListPeople(ctx, search, limit, offset)
}

func (s *adminService) GetPersonDetails(ctx context.Context, id uuid.UUID) (*models.User, []*models.AdminOrder, []*models.VendorApplication, []*models.ProductListing, error) {
	return s.store.Admin().GetPersonDetails(ctx, id)
}

func (s *adminService) SetPersonStatus(ctx context.Context, id uuid.UUID, isSuspended bool, actor *models.AdminClaims, ip string) error {
	action := "ACTIVATE"
	if isSuspended {
		action = "SUSPEND"
	}
	actorID, _ := uuid.Parse(actor.AdminID)
	err := s.store.Admin().SetPersonStatus(ctx, id, isSuspended)
	if err == nil {
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), action, "user", id.String(), nil, map[string]bool{"suspended": isSuspended}, ip)
	}
	return err
}

// -----------------------------------------------------------------------------
// Vendor Applications
// -----------------------------------------------------------------------------

func (s *adminService) ListVendorApplications(ctx context.Context, status string, limit, offset int) ([]*models.VendorApplication, int64, error) {
	return s.store.Admin().ListVendorApplications(ctx, status, limit, offset)
}

func (s *adminService) GetVendorApplication(ctx context.Context, id uuid.UUID) (*models.VendorApplication, error) {
	return s.store.Admin().GetVendorApplication(ctx, id)
}

func (s *adminService) ApproveVendorApplication(ctx context.Context, id uuid.UUID, actor *models.AdminClaims, ip string) error {
	app, err := s.store.Admin().GetVendorApplication(ctx, id)
	if err != nil {
		return err
	}
	actorID, _ := uuid.Parse(actor.AdminID)
	app.Status = "approved"
	app.ReviewedBy = &actorID
	err = s.store.Admin().UpdateVendorApplication(ctx, app)
	if err == nil {
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "APPROVE", "vendor_application", id.String(), nil, app, ip)
	}
	return err
}

func (s *adminService) RejectVendorApplication(ctx context.Context, id uuid.UUID, reason string, actor *models.AdminClaims, ip string) error {
	app, err := s.store.Admin().GetVendorApplication(ctx, id)
	if err != nil {
		return err
	}
	actorID, _ := uuid.Parse(actor.AdminID)
	app.Status = "rejected"
	app.RejectionReason = reason
	app.ReviewedBy = &actorID
	err = s.store.Admin().UpdateVendorApplication(ctx, app)
	if err == nil {
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "REJECT", "vendor_application", id.String(), nil, app, ip)
	}
	return err
}

func (s *adminService) RequestInfoVendorApplication(ctx context.Context, id uuid.UUID, notes string, actor *models.AdminClaims, ip string) error {
	app, err := s.store.Admin().GetVendorApplication(ctx, id)
	if err != nil {
		return err
	}
	actorID, _ := uuid.Parse(actor.AdminID)
	app.Status = "info_requested"
	app.InfoRequestNotes = notes
	app.ReviewedBy = &actorID
	err = s.store.Admin().UpdateVendorApplication(ctx, app)
	if err == nil {
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "REQUEST_INFO", "vendor_application", id.String(), nil, app, ip)
	}
	return err
}

// -----------------------------------------------------------------------------
// Services & Categories Tree Hierarchy
// -----------------------------------------------------------------------------

func (s *adminService) ListCategoriesTree(ctx context.Context) ([]*models.ServiceCategory, error) {
	flat, err := s.store.Admin().ListCategories(ctx)
	if err != nil {
		return nil, err
	}

	categoryMap := make(map[uuid.UUID]*models.ServiceCategory)
	for _, c := range flat {
		categoryMap[c.ID] = c
	}

	var rootCategories []*models.ServiceCategory
	for _, c := range flat {
		if c.ParentID == nil {
			rootCategories = append(rootCategories, c)
		} else {
			if parent, exists := categoryMap[*c.ParentID]; exists {
				parent.Children = append(parent.Children, c)
			} else {
				rootCategories = append(rootCategories, c)
			}
		}
	}

	return rootCategories, nil
}

func (s *adminService) CreateCategory(ctx context.Context, cat *models.ServiceCategory, actor *models.AdminClaims, ip string) (*models.ServiceCategory, error) {
	if cat.Slug == "" {
		cat.Slug = strings.ToLower(strings.ReplaceAll(cat.Name, " ", "-"))
	}
	err := s.store.Admin().CreateCategory(ctx, cat)
	if err == nil {
		actorID, _ := uuid.Parse(actor.AdminID)
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "CREATE", "category", cat.ID.String(), nil, cat, ip)
	}
	return cat, err
}

func (s *adminService) UpdateCategory(ctx context.Context, cat *models.ServiceCategory, actor *models.AdminClaims, ip string) (*models.ServiceCategory, error) {
	err := s.store.Admin().UpdateCategory(ctx, cat)
	if err == nil {
		actorID, _ := uuid.Parse(actor.AdminID)
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "UPDATE", "category", cat.ID.String(), nil, cat, ip)
	}
	return cat, err
}

func (s *adminService) DeleteCategory(ctx context.Context, id uuid.UUID, actor *models.AdminClaims, ip string) error {
	err := s.store.Admin().DeleteCategory(ctx, id)
	if err == nil {
		actorID, _ := uuid.Parse(actor.AdminID)
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "DELETE", "category", id.String(), nil, nil, ip)
	}
	return err
}

// -----------------------------------------------------------------------------
// Dynamic Form Definitions
// -----------------------------------------------------------------------------

func (s *adminService) GetFormDefinition(ctx context.Context, categoryID uuid.UUID) (*models.FormDefinition, error) {
	return s.store.Admin().GetFormDefinition(ctx, categoryID)
}

func (s *adminService) SaveFormDefinition(ctx context.Context, form *models.FormDefinition, actor *models.AdminClaims, ip string) (*models.FormDefinition, error) {
	actorID, _ := uuid.Parse(actor.AdminID)
	form.CreatedBy = &actorID
	err := s.store.Admin().SaveFormDefinition(ctx, form)
	if err == nil {
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "SAVE", "form_definition", form.ID.String(), nil, form, ip)
	}
	return form, err
}

// -----------------------------------------------------------------------------
// Listings
// -----------------------------------------------------------------------------

func (s *adminService) ListListings(ctx context.Context, status string, limit, offset int) ([]*models.ProductListing, int64, error) {
	return s.store.Admin().ListListings(ctx, status, limit, offset)
}

func (s *adminService) UpdateListingApproval(ctx context.Context, id uuid.UUID, approvalStatus string, actor *models.AdminClaims, ip string) error {
	err := s.store.Admin().UpdateListingApproval(ctx, id, approvalStatus)
	if err == nil {
		actorID, _ := uuid.Parse(actor.AdminID)
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "APPROVE_LISTING", "listing", id.String(), nil, map[string]string{"approval": approvalStatus}, ip)
	}
	return err
}

func (s *adminService) UpdateListingStatus(ctx context.Context, id uuid.UUID, isActive bool, actor *models.AdminClaims, ip string) error {
	err := s.store.Admin().UpdateListingActiveStatus(ctx, id, isActive)
	if err == nil {
		actorID, _ := uuid.Parse(actor.AdminID)
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "UPDATE_LISTING_STATUS", "listing", id.String(), nil, map[string]bool{"active": isActive}, ip)
	}
	return err
}

// -----------------------------------------------------------------------------
// Orders
// -----------------------------------------------------------------------------

func (s *adminService) ListOrders(ctx context.Context, status, search string, limit, offset int) ([]*models.AdminOrder, int64, error) {
	return s.store.Admin().ListOrders(ctx, status, search, limit, offset)
}

func (s *adminService) GetOrder(ctx context.Context, id uuid.UUID) (*models.AdminOrder, error) {
	return s.store.Admin().GetOrder(ctx, id)
}

func (s *adminService) ResolveOrderDispute(ctx context.Context, id uuid.UUID, resolution string, actor *models.AdminClaims, ip string) error {
	actorID, _ := uuid.Parse(actor.AdminID)
	err := s.store.Admin().UpdateOrderDispute(ctx, id, resolution, actorID)
	if err == nil {
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "RESOLVE_DISPUTE", "order", id.String(), nil, map[string]string{"resolution": resolution}, ip)
	}
	return err
}

// -----------------------------------------------------------------------------
// Requests & Quotations
// -----------------------------------------------------------------------------

func (s *adminService) ListQuotationRequests(ctx context.Context, status string, limit, offset int) ([]*models.QuotationRequest, int64, error) {
	return s.store.Admin().ListQuotationRequests(ctx, status, limit, offset)
}

func (s *adminService) GetQuotationRequest(ctx context.Context, id uuid.UUID) (*models.QuotationRequest, error) {
	return s.store.Admin().GetQuotationRequest(ctx, id)
}

// -----------------------------------------------------------------------------
// Payments & Commission
// -----------------------------------------------------------------------------

func (s *adminService) ListPayments(ctx context.Context, paymentType, status string, limit, offset int) ([]*models.PaymentRecord, int64, error) {
	return s.store.Admin().ListPayments(ctx, paymentType, status, limit, offset)
}

func (s *adminService) ListCommissionRules(ctx context.Context) ([]*models.CommissionRule, error) {
	return s.store.Admin().ListCommissionRules(ctx)
}

func (s *adminService) SetCommissionRule(ctx context.Context, rule *models.CommissionRule, actor *models.AdminClaims, ip string) error {
	err := s.store.Admin().SetCommissionRule(ctx, rule)
	if err == nil {
		actorID, _ := uuid.Parse(actor.AdminID)
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "SET_COMMISSION", "commission_rule", rule.ID.String(), nil, rule, ip)
	}
	return err
}

// -----------------------------------------------------------------------------
// Admin Management (Super Admin only)
// -----------------------------------------------------------------------------

func (s *adminService) ListAdmins(ctx context.Context) ([]*models.AdminUser, error) {
	return s.store.Admin().ListAdmins(ctx)
}

func (s *adminService) CreateAdmin(ctx context.Context, admin *models.AdminUser, password string, actor *models.AdminClaims, ip string) (*models.AdminUser, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}
	admin.PasswordHash = string(hash)
	err = s.store.Admin().CreateAdmin(ctx, admin)
	if err == nil {
		actorID, _ := uuid.Parse(actor.AdminID)
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "CREATE_ADMIN", "admin", admin.ID.String(), nil, admin, ip)
	}
	return admin, err
}

func (s *adminService) UpdateAdmin(ctx context.Context, admin *models.AdminUser, actor *models.AdminClaims, ip string) (*models.AdminUser, error) {
	err := s.store.Admin().UpdateAdmin(ctx, admin)
	if err == nil {
		actorID, _ := uuid.Parse(actor.AdminID)
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "UPDATE_ADMIN", "admin", admin.ID.String(), nil, admin, ip)
	}
	return admin, err
}

// -----------------------------------------------------------------------------
// Audit Logs
// -----------------------------------------------------------------------------

func (s *adminService) ListAuditLogs(ctx context.Context, entityType, action string, limit, offset int) ([]*models.AuditLog, int64, error) {
	return s.store.Admin().ListAuditLogs(ctx, entityType, action, limit, offset)
}

// -----------------------------------------------------------------------------
// Settings
// -----------------------------------------------------------------------------

func (s *adminService) GetSettings(ctx context.Context) (map[string]interface{}, error) {
	return s.store.Admin().GetSettings(ctx)
}

func (s *adminService) UpdateSetting(ctx context.Context, key string, val interface{}, actor *models.AdminClaims, ip string) error {
	actorID, _ := uuid.Parse(actor.AdminID)
	err := s.store.Admin().UpdateSetting(ctx, key, val, actorID)
	if err == nil {
		_ = s.logAction(ctx, actorID, actor.FullName, string(actor.Role), "UPDATE_SETTING", "setting", key, nil, val, ip)
	}
	return err
}
