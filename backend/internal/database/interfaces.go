package database

import (
	"context"
	"errors"
	"time"

	"dodo-universe-backend/internal/models"
	"github.com/google/uuid"
)

var (
	ErrNotFound                 = errors.New("record not found")
	ErrAlreadyExists            = errors.New("record already exists")
	ErrChallengeAlreadyConsumed = errors.New("challenge already consumed, expired or locked out")
	ErrSessionAlreadyRevoked    = errors.New("session already revoked or expired")
)

// Store defines the aggregated data store interface.
type Store interface {
	Users() UserRepository
	PendingRegistrations() PendingRegistrationRepository
	OTPChallenges() OTPChallengeRepository
	Sessions() SessionRepository
	DevTestNumbers() DevTestNumberRepository
	Admin() AdminRepository
	WithTx(ctx context.Context, fn func(tx Store) error) error
	Close() error
	Ping(ctx context.Context) error
}

// UserRepository handles persistence for user accounts.
type UserRepository interface {
	FindByID(ctx context.Context, id uuid.UUID) (*models.User, error)
	FindByPhone(ctx context.Context, phone string) (*models.User, error)
	FindByEmail(ctx context.Context, email string) (*models.User, error)
	Create(ctx context.Context, user *models.User) error
	Update(ctx context.Context, user *models.User) error
}

// PendingRegistrationRepository manages unverified registration sessions.
type PendingRegistrationRepository interface {
	CreateOrReplace(ctx context.Context, reg *models.PendingRegistration) error
	FindByTokenHash(ctx context.Context, tokenHash string) (*models.PendingRegistration, error)
	FindByMobile(ctx context.Context, mobile string) (*models.PendingRegistration, error)
	Delete(ctx context.Context, id uuid.UUID) error
}

// OTPChallengeRepository manages isolated OTP verification challenges.
type OTPChallengeRepository interface {
	Create(ctx context.Context, challenge *models.OTPChallenge) error
	FindLatestActive(ctx context.Context, purpose models.OTPPurpose, destination string) (*models.OTPChallenge, error)
	IncrementFailedAttempts(ctx context.Context, id uuid.UUID) (int, error)
	MarkConsumed(ctx context.Context, id uuid.UUID, verifiedAt time.Time) error
	Delete(ctx context.Context, id uuid.UUID) error
}

// DevTestNumberRepository handles development-only test number configurations.
type DevTestNumberRepository interface {
	FindByPhone(ctx context.Context, phone string) (*models.DevTestNumber, error)
	Set(ctx context.Context, entry *models.DevTestNumber) error
}

// SessionRepository manages refresh tokens.
type SessionRepository interface {
	Create(ctx context.Context, session *models.Session) error
	FindByTokenHash(ctx context.Context, tokenHash string) (*models.Session, error)
	Revoke(ctx context.Context, id uuid.UUID) error
	RevokeAllForUser(ctx context.Context, userID uuid.UUID) error
}

// AdminRepository provides administrative data access across all 14 modules.
type AdminRepository interface {
	// 1. Admin Authentication & RBAC
	FindAdminByID(ctx context.Context, id uuid.UUID) (*models.AdminUser, error)
	FindAdminByEmailOrPhone(ctx context.Context, identifier string) (*models.AdminUser, error)
	CreateAdmin(ctx context.Context, admin *models.AdminUser) error
	UpdateAdmin(ctx context.Context, admin *models.AdminUser) error
	ListAdmins(ctx context.Context) ([]*models.AdminUser, error)
	RecordAdminFailedLogin(ctx context.Context, id uuid.UUID, lockUntil *time.Time) error
	ResetAdminFailedLogins(ctx context.Context, id uuid.UUID) error
	CreateAdminSession(ctx context.Context, session *models.AdminSession) error
	FindAdminSessionByTokenHash(ctx context.Context, tokenHash string) (*models.AdminSession, error)
	RevokeAdminSession(ctx context.Context, id uuid.UUID) error

	// 2. Dashboard KPIs & Aggregations (Live Postgres counts only)
	GetDashboardMetrics(ctx context.Context) (*models.AdminDashboardMetrics, error)

	// 3. People Management (Unified app_users accounts)
	ListPeople(ctx context.Context, search string, limit, offset int) ([]*models.User, int64, error)
	GetPersonDetails(ctx context.Context, id uuid.UUID) (*models.User, []*models.AdminOrder, []*models.VendorApplication, []*models.ProductListing, error)
	SetPersonStatus(ctx context.Context, id uuid.UUID, isSuspended bool) error

	// 4. Vendor Applications
	ListVendorApplications(ctx context.Context, status string, limit, offset int) ([]*models.VendorApplication, int64, error)
	GetVendorApplication(ctx context.Context, id uuid.UUID) (*models.VendorApplication, error)
	UpdateVendorApplication(ctx context.Context, app *models.VendorApplication) error

	// 5. Services & Categories (Unlimited depth hierarchy)
	ListCategories(ctx context.Context) ([]*models.ServiceCategory, error)
	CreateCategory(ctx context.Context, cat *models.ServiceCategory) error
	UpdateCategory(ctx context.Context, cat *models.ServiceCategory) error
	DeleteCategory(ctx context.Context, id uuid.UUID) error

	// 6. Dynamic Form Definitions
	GetFormDefinition(ctx context.Context, categoryID uuid.UUID) (*models.FormDefinition, error)
	SaveFormDefinition(ctx context.Context, form *models.FormDefinition) error

	// 7. Products & Listings
	ListListings(ctx context.Context, status string, limit, offset int) ([]*models.ProductListing, int64, error)
	UpdateListingApproval(ctx context.Context, id uuid.UUID, status string) error
	UpdateListingActiveStatus(ctx context.Context, id uuid.UUID, isActive bool) error

	// 8. Bookings & Orders
	ListOrders(ctx context.Context, status string, search string, limit, offset int) ([]*models.AdminOrder, int64, error)
	GetOrder(ctx context.Context, id uuid.UUID) (*models.AdminOrder, error)
	UpdateOrderDispute(ctx context.Context, id uuid.UUID, resolution string, adminID uuid.UUID) error

	// 9. Requests & Quotations
	ListQuotationRequests(ctx context.Context, status string, limit, offset int) ([]*models.QuotationRequest, int64, error)
	GetQuotationRequest(ctx context.Context, id uuid.UUID) (*models.QuotationRequest, error)

	// 10. Payments & Commission
	ListPayments(ctx context.Context, paymentType, status string, limit, offset int) ([]*models.PaymentRecord, int64, error)
	ListCommissionRules(ctx context.Context) ([]*models.CommissionRule, error)
	SetCommissionRule(ctx context.Context, rule *models.CommissionRule) error

	// 11. Audit Logs
	CreateAuditLog(ctx context.Context, log *models.AuditLog) error
	ListAuditLogs(ctx context.Context, entityType, action string, limit, offset int) ([]*models.AuditLog, int64, error)

	// 12. Settings
	GetSettings(ctx context.Context) (map[string]interface{}, error)
	UpdateSetting(ctx context.Context, key string, val interface{}, adminID uuid.UUID) error
}
