package models

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// UserRole represents authorization roles in the platform.
type UserRole string

const (
	RoleUser     UserRole = "user"
	RoleCustomer UserRole = "customer"
	RoleProvider UserRole = "provider"
	RoleAdmin    UserRole = "admin"
)

// OTPPurpose defines separate scopes for verification challenges.
type OTPPurpose string

const (
	OTPPurposeMobileRegistration OTPPurpose = "mobile_registration"
	OTPPurposeEmailRegistration  OTPPurpose = "email_registration"
	OTPPurposeLogin              OTPPurpose = "login"
)

// User represents an authenticated application user account.
type User struct {
	ID                     uuid.UUID  `json:"id"`
	Phone                  string     `json:"phone"`
	PhoneConfirmedAt       *time.Time `json:"phone_confirmed_at,omitempty"`
	Email                  *string    `json:"email,omitempty"`
	EmailConfirmedAt       *time.Time `json:"email_confirmed_at,omitempty"`
	FullName               string     `json:"full_name"`
	Role                   UserRole   `json:"role"`
	IsRegistrationComplete bool       `json:"is_registration_complete"`
	CreatedAt              time.Time  `json:"created_at"`
	UpdatedAt              time.Time  `json:"updated_at"`
}

// PendingRegistration represents a two-step registration session.
type PendingRegistration struct {
	ID                    uuid.UUID  `json:"id"`
	UserID                uuid.UUID  `json:"user_id"`
	MobileNumber          string     `json:"mobile_number"`
	Email                 string     `json:"email"`
	FullName              string     `json:"full_name"`
	RegistrationTokenHash string     `json:"-"`
	IsMobileVerified      bool       `json:"is_mobile_verified"`
	IsEmailVerified       bool       `json:"is_email_verified"`
	ExpiresAt             time.Time  `json:"expires_at"`
	CreatedAt             time.Time  `json:"created_at"`
	VerifiedAt            *time.Time `json:"verified_at,omitempty"`
}

// OTPChallenge represents an isolated, single-purpose verification challenge.
type OTPChallenge struct {
	ID             uuid.UUID   `json:"id"`
	Purpose        OTPPurpose  `json:"purpose"`
	Destination    string      `json:"destination"` // normalized phone or email
	OTPHash        string      `json:"-"`
	ReferenceID    *uuid.UUID  `json:"reference_id,omitempty"`
	FailedAttempts int         `json:"failed_attempts"`
	MaxAttempts    int         `json:"max_attempts"`
	IsConsumed     bool        `json:"is_consumed"`
	ExpiresAt      time.Time   `json:"expires_at"`
	CreatedAt      time.Time   `json:"created_at"`
	VerifiedAt     *time.Time  `json:"verified_at,omitempty"`
}

// DevTestNumber represents a development test number with an optional fixed test OTP.
type DevTestNumber struct {
	ID           uuid.UUID `json:"id"`
	MobileNumber string    `json:"mobile_number"`
	TestOTP      string    `json:"test_otp,omitempty"`
	TestOTPHash  string    `json:"-"`
	IsEnabled    bool      `json:"is_enabled"`
}

// Session represents an active refresh token session.
type Session struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	TokenHash string     `json:"-"`
	ExpiresAt time.Time  `json:"expires_at"`
	CreatedAt time.Time  `json:"created_at"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
}

// UserClaims defines custom JWT claims for access tokens.
type UserClaims struct {
	UserID   string   `json:"sub"`
	Phone    string   `json:"phone"`
	Email    string   `json:"email,omitempty"`
	FullName string   `json:"full_name,omitempty"`
	Role     UserRole `json:"role"`
	jwt.RegisteredClaims
}

// AuthTokens bundles access and refresh tokens for clients.
type AuthTokens struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int64  `json:"expires_in"` // seconds
}

// AuthResponse represents the standard payload returned upon successful auth.
type AuthResponse struct {
	User   *User       `json:"user"`
	Tokens *AuthTokens `json:"tokens"`
}
