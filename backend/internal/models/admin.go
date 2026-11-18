package models

import (
	"encoding/json"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// AdminRole represents authorization tiers for administrative access.
type AdminRole string

const (
	AdminRoleSuper      AdminRole = "super_admin"
	AdminRoleOperations AdminRole = "operations_admin"
	AdminRoleFinance    AdminRole = "finance_admin"
)

// AdminUser represents a platform administrator.
type AdminUser struct {
	ID                  uuid.UUID  `json:"id"`
	Email               string     `json:"email"`
	Phone               string     `json:"phone"`
	PasswordHash        string     `json:"-"`
	FullName            string     `json:"full_name"`
	Role                AdminRole  `json:"role"`
	IsActive            bool       `json:"is_active"`
	FailedLoginAttempts int        `json:"failed_login_attempts"`
	LockedUntil         *time.Time `json:"locked_until,omitempty"`
	LastLoginAt         *time.Time `json:"last_login_at,omitempty"`
	CreatedAt           time.Time  `json:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at"`
}

// AdminSession represents a refresh token session for an admin.
type AdminSession struct {
	ID        uuid.UUID  `json:"id"`
	AdminID   uuid.UUID  `json:"admin_id"`
	TokenHash string     `json:"-"`
	ExpiresAt time.Time  `json:"expires_at"`
	CreatedAt time.Time  `json:"created_at"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
}

// AdminClaims defines JWT claims for administrators.
type AdminClaims struct {
	AdminID  string    `json:"sub"`
	Email    string    `json:"email"`
	Phone    string    `json:"phone"`
	FullName string    `json:"full_name"`
	Role     AdminRole `json:"role"`
	jwt.RegisteredClaims
}

// AuditLog tracks every administrative change.
type AuditLog struct {
	ID         uuid.UUID       `json:"id"`
	AdminID    *uuid.UUID      `json:"admin_id,omitempty"`
	AdminName  string          `json:"admin_name"`
	AdminRole  string          `json:"admin_role"`
	Action     string          `json:"action"`
	EntityType string          `json:"entity_type"`
	EntityID   string          `json:"entity_id"`
	OldValues  json.RawMessage `json:"old_values,omitempty"`
	NewValues  json.RawMessage `json:"new_values,omitempty"`
	IPAddress  string          `json:"ip_address,omitempty"`
	CreatedAt  time.Time       `json:"created_at"`
}

// ServiceCategory represents a hierarchical service or product category.
type ServiceCategory struct {
	ID            uuid.UUID          `json:"id"`
	ParentID      *uuid.UUID         `json:"parent_id,omitempty"`
	Name          string             `json:"name"`
	Slug          string             `json:"slug"`
	Description   string             `json:"description,omitempty"`
	IconURL       string             `json:"icon_url,omitempty"`
	IsActive      bool               `json:"is_active"`
	SortOrder     int                `json:"sort_order"`
	CategoryType  string             `json:"category_type"`
	AllowListings bool               `json:"allow_listings"`
	Children      []*ServiceCategory `json:"children,omitempty"`
	CreatedAt     time.Time          `json:"created_at"`
	UpdatedAt     time.Time          `json:"updated_at"`
}

// FormDefinition defines dynamic service-specific vendor application forms.
type FormDefinition struct {
	ID          uuid.UUID       `json:"id"`
	CategoryID  uuid.UUID       `json:"category_id"`
	Title       string          `json:"title"`
	Description string          `json:"description,omitempty"`
	Status      string          `json:"status"` // draft, published, archived
	Version     int             `json:"version"`
	Schema      json.RawMessage `json:"schema"`
	CreatedBy   *uuid.UUID      `json:"created_by,omitempty"`
	CreatedAt   time.Time       `json:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at"`
}

// VendorApplication represents a vendor's registration and verification review.
type VendorApplication struct {
	ID                uuid.UUID       `json:"id"`
	UserID            uuid.UUID       `json:"user_id"`
	UserFullName      string          `json:"user_full_name,omitempty"`
	UserPhone         string          `json:"user_phone,omitempty"`
	UserEmail         string          `json:"user_email,omitempty"`
	CategoryID        *uuid.UUID      `json:"category_id,omitempty"`
	CategoryName      string          `json:"category_name,omitempty"`
	BusinessName      string          `json:"business_name"`
	BusinessType      string          `json:"business_type,omitempty"`
	Status            string          `json:"status"` // pending, under_review, approved, rejected, info_requested
	SubmittedData     json.RawMessage `json:"submitted_data"`
	Documents         json.RawMessage `json:"documents"`
	RejectionReason   string          `json:"rejection_reason,omitempty"`
	InfoRequestNotes  string          `json:"info_request_notes,omitempty"`
	ReviewedBy        *uuid.UUID      `json:"reviewed_by,omitempty"`
	ReviewedAt        *time.Time      `json:"reviewed_at,omitempty"`
	CreatedAt         time.Time       `json:"created_at"`
	UpdatedAt         time.Time       `json:"updated_at"`
}

// ProductListing represents vendor products or services configured on the platform.
type ProductListing struct {
	ID                 uuid.UUID `json:"id"`
	VendorID           uuid.UUID `json:"vendor_id"`
	VendorName         string    `json:"vendor_name,omitempty"`
	CategoryID         uuid.UUID `json:"category_id"`
	CategoryName       string    `json:"category_name,omitempty"`
	Title              string    `json:"title"`
	Description        string    `json:"description,omitempty"`
	ListingType        string    `json:"listing_type"`
	UnitPrice          float64   `json:"unit_price"`
	PricingUnit        string    `json:"pricing_unit"`
	MinOrderQuantity   float64   `json:"min_order_quantity"`
	HasTransportation  bool      `json:"has_transportation"`
	TransportationFee  float64   `json:"transportation_fee"`
	IsActive           bool      `json:"is_active"`
	ApprovalStatus     string    `json:"approval_status"`
	CreatedAt          time.Time `json:"created_at"`
	UpdatedAt          time.Time `json:"updated_at"`
}

// AdminOrder represents an order viewed from the administrator perspective.
type AdminOrder struct {
	ID                uuid.UUID       `json:"id"`
	CustomerID        uuid.UUID       `json:"customer_id"`
	CustomerName      string          `json:"customer_name,omitempty"`
	CustomerPhone     string          `json:"customer_phone,omitempty"`
	VendorID          uuid.UUID       `json:"vendor_id"`
	VendorName        string          `json:"vendor_name,omitempty"`
	VendorPhone       string          `json:"vendor_phone,omitempty"`
	ListingID         *uuid.UUID      `json:"listing_id,omitempty"`
	ListingTitle      string          `json:"listing_title,omitempty"`
	Status            string          `json:"status"`
	TotalAmount       float64         `json:"total_amount"`
	CommissionAmount  float64         `json:"commission_amount"`
	OrderDetails      json.RawMessage `json:"order_details"`
	DisputeReason     string          `json:"dispute_reason,omitempty"`
	DisputeResolution string          `json:"dispute_resolution,omitempty"`
	ResolvedBy        *uuid.UUID      `json:"resolved_by,omitempty"`
	ResolvedAt        *time.Time      `json:"resolved_at,omitempty"`
	CreatedAt         time.Time       `json:"created_at"`
	UpdatedAt         time.Time       `json:"updated_at"`
}

// QuotationRequest represents an RFQ submitted by a customer.
type QuotationRequest struct {
	ID            uuid.UUID       `json:"id"`
	CustomerID    uuid.UUID       `json:"customer_id"`
	CustomerName  string          `json:"customer_name,omitempty"`
	CategoryID    *uuid.UUID      `json:"category_id,omitempty"`
	CategoryName  string          `json:"category_name,omitempty"`
	Title         string          `json:"title"`
	Details       json.RawMessage `json:"details"`
	Status        string          `json:"status"`
	Quotations    []*Quotation    `json:"quotations,omitempty"`
	CreatedAt     time.Time       `json:"created_at"`
	UpdatedAt     time.Time       `json:"updated_at"`
}

// Quotation represents a vendor's bid on a customer's quotation request.
type Quotation struct {
	ID           uuid.UUID `json:"id"`
	RequestID    uuid.UUID `json:"request_id"`
	VendorID     uuid.UUID `json:"vendor_id"`
	VendorName   string    `json:"vendor_name,omitempty"`
	OfferedPrice float64   `json:"offered_price"`
	Notes        string    `json:"notes,omitempty"`
	Status       string    `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// PaymentRecord represents a financial ledger entry.
type PaymentRecord struct {
	ID              uuid.UUID  `json:"id"`
	OrderID         *uuid.UUID `json:"order_id,omitempty"`
	PayerID         *uuid.UUID `json:"payer_id,omitempty"`
	PayerName       string     `json:"payer_name,omitempty"`
	Amount          float64    `json:"amount"`
	PaymentType     string     `json:"payment_type"`
	Status          string     `json:"status"`
	ReferenceNumber string     `json:"reference_number,omitempty"`
	Notes           string     `json:"notes,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

// CommissionRule defines category-specific platform commission.
type CommissionRule struct {
	ID                uuid.UUID  `json:"id"`
	CategoryID        *uuid.UUID `json:"category_id,omitempty"`
	CategoryName      string     `json:"category_name,omitempty"`
	CommissionPercent float64    `json:"commission_percent"`
	FixedFee          float64    `json:"fixed_fee"`
	IsActive          bool       `json:"is_active"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

// AdminDashboardMetrics holds real-time aggregated counts from PostgreSQL.
type AdminDashboardMetrics struct {
	TotalPeople                int64   `json:"total_people"`
	ActiveVendors              int64   `json:"active_vendors"`
	PendingVendorApplications  int64   `json:"pending_vendor_applications"`
	TotalServices              int64   `json:"total_services"`
	TotalCategories            int64   `json:"total_categories"`
	TotalListings              int64   `json:"total_listings"`
	TotalOrders                int64   `json:"total_orders"`
	PendingOrders              int64   `json:"pending_orders"`
	CompletedOrders            int64   `json:"completed_orders"`
	CancelledOrders            int64   `json:"cancelled_orders"`
	PendingQuoteRequests       int64   `json:"pending_quote_requests"`
	TotalPaymentVolume         float64 `json:"total_payment_volume"`
	RecentActivity             []*AuditLog `json:"recent_activity"`
}

// AdminAuthResponse returns tokens and profile upon admin authentication.
type AdminAuthResponse struct {
	Admin  *AdminUser  `json:"admin"`
	Tokens *AuthTokens `json:"tokens"`
}
