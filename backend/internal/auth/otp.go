package auth

import (
	"context"
	"crypto/rand"
	"fmt"
	"log"
	"math/big"
	"strings"
	"sync"
	"time"

	"dodo-universe-backend/internal/database"
	"golang.org/x/crypto/bcrypt"
)

const (
	OTPExpiryDuration = 15 * time.Minute
	MaxOTPAttempts    = 5
)

// SMSProvider dispatches SMS messages (e.g., via Twilio, AWS SNS, Msg91 in production).
type SMSProvider interface {
	SendSMS(ctx context.Context, to, message string) error
}

// EmailProvider dispatches emails (e.g., via SendGrid, SES, Resend in production).
type EmailProvider interface {
	SendEmail(ctx context.Context, to, subject, body string) error
}

// DevDeliveryRecorder records dispatched OTPs in memory for development inspection and tests.
type DevDeliveryRecorder interface {
	RecordSMS(to, message, otp string)
	RecordEmail(to, subject, body, otp string)
	GetLastSMS(to string) (string, bool)
	GetLastEmail(to string) (string, bool)
}

// InMemDeliveryRecorder is an in-memory recorder for dev/test delivery tracking.
type InMemDeliveryRecorder struct {
	mu     sync.RWMutex
	sms    map[string]string // to -> last OTP
	emails map[string]string // to -> last OTP
}

// NewInMemDeliveryRecorder creates a new InMemDeliveryRecorder.
func NewInMemDeliveryRecorder() *InMemDeliveryRecorder {
	return &InMemDeliveryRecorder{
		sms:    make(map[string]string),
		emails: make(map[string]string),
	}
}

func (r *InMemDeliveryRecorder) RecordSMS(to, message, otp string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sms[to] = otp
	log.Printf("[DEV SMS] To: %s | OTP: %s | Message: %s", to, otp, message)
}

func (r *InMemDeliveryRecorder) RecordEmail(to, subject, body, otp string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.emails[strings.ToLower(to)] = otp
	log.Printf("[DEV EMAIL] To: %s | OTP: %s | Subject: %s", to, otp, subject)
}

func (r *InMemDeliveryRecorder) GetLastSMS(to string) (string, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	otp, ok := r.sms[to]
	return otp, ok
}

func (r *InMemDeliveryRecorder) GetLastEmail(to string) (string, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	otp, ok := r.emails[strings.ToLower(to)]
	return otp, ok
}

// OTPProvider handles OTP generation, hashing, and verification.
type OTPProvider struct {
	isDevMode      bool
	fallbackDevOTP string
	devTestNumbers database.DevTestNumberRepository
	smsProvider    SMSProvider
	emailProvider  EmailProvider
	devRecorder    DevDeliveryRecorder
}

// NewOTPProvider creates an OTPProvider.
func NewOTPProvider(
	isDevMode bool,
	fallbackDevOTP string,
	devTestNumbers database.DevTestNumberRepository,
	smsProvider SMSProvider,
	emailProvider EmailProvider,
	devRecorder DevDeliveryRecorder,
) *OTPProvider {
	if fallbackDevOTP == "" {
		fallbackDevOTP = "123456"
	}
	return &OTPProvider{
		isDevMode:      isDevMode,
		fallbackDevOTP: fallbackDevOTP,
		devTestNumbers: devTestNumbers,
		smsProvider:    smsProvider,
		emailProvider:  emailProvider,
		devRecorder:    devRecorder,
	}
}

// GenerateOTP produces an OTP code. In dev mode for registered test numbers, it returns their fixed OTP.
// In dev mode without a custom test number, it returns the configured fallbackDevOTP (123456).
// In production mode, it ALWAYS generates a cryptographically secure random 6-digit code.
func (p *OTPProvider) GenerateOTP(ctx context.Context, destination string) (string, error) {
	if p.isDevMode {
		if p.devTestNumbers != nil && destination != "" {
			entry, err := p.devTestNumbers.FindByPhone(ctx, destination)
			if err == nil && entry != nil && entry.IsEnabled && entry.TestOTP != "" {
				return entry.TestOTP, nil
			}
		}
		return p.fallbackDevOTP, nil
	}

	// Cryptographically secure random 6-digit code
	n, err := rand.Int(rand.Reader, big.NewInt(900000))
	if err != nil {
		return "", fmt.Errorf("failed to generate random OTP: %w", err)
	}
	return fmt.Sprintf("%06d", n.Int64()+100000), nil
}

// HashOTP creates a bcrypt hash of the OTP.
func (p *OTPProvider) HashOTP(otp string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(otp), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("failed to hash OTP: %w", err)
	}
	return string(bytes), nil
}

// VerifyOTP validates the OTP.
// In development:
// 1. If destination matches a registered test number in devTestNumbers, that custom OTP is accepted.
// 2. The fallbackDevOTP (123456) is accepted.
// 3. Stored bcrypt hash is accepted.
// In production:
// ONLY the stored bcrypt hash is validated. Development bypass is strictly disabled.
func (p *OTPProvider) VerifyOTP(ctx context.Context, destination, providedOTP, storedHash string) bool {
	if p.isDevMode {
		if p.devTestNumbers != nil && destination != "" {
			entry, err := p.devTestNumbers.FindByPhone(ctx, destination)
			if err == nil && entry != nil && entry.IsEnabled && entry.TestOTP != "" {
				if providedOTP == entry.TestOTP {
					return true
				}
			}
		}
		if providedOTP == p.fallbackDevOTP {
			return true
		}
	}

	if storedHash == "" {
		return false
	}
	err := bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(providedOTP))
	return err == nil
}

// SendSMS dispatches an SMS or records it in dev mode.
func (p *OTPProvider) SendSMS(ctx context.Context, to, message, otp string) error {
	if p.isDevMode && p.devRecorder != nil {
		p.devRecorder.RecordSMS(to, message, otp)
	}
	if p.smsProvider != nil {
		return p.smsProvider.SendSMS(ctx, to, message)
	}
	return nil
}

// SendEmail dispatches an email or records it in dev mode.
func (p *OTPProvider) SendEmail(ctx context.Context, to, subject, body, otp string) error {
	if p.isDevMode && p.devRecorder != nil {
		p.devRecorder.RecordEmail(to, subject, body, otp)
	}
	if p.emailProvider != nil {
		return p.emailProvider.SendEmail(ctx, to, subject, body)
	}
	return nil
}
