package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"dodo-universe-backend/internal/database"
	"dodo-universe-backend/internal/models"
	"dodo-universe-backend/pkg/validator"
	"github.com/google/uuid"
)

var (
	ErrUserNotFound        = errors.New("user account not found")
	ErrUserAlreadyExists   = errors.New("an account with this mobile number or email already exists")
	ErrInvalidOTP          = errors.New("invalid verification code")
	ErrOTPExpired          = errors.New("verification code has expired, please request a new one")
	ErrMaxAttemptsExceeded = errors.New("too many failed attempts, please restart verification")
	ErrInvalidSession      = errors.New("invalid or expired session")
	ErrUnauthorized        = errors.New("unauthorized request")
	ErrMobileNotVerified   = errors.New("mobile number must be verified before email")
	ErrEmailMismatch       = errors.New("email does not match the registration session")
	ErrDeliveryFailed      = errors.New("failed to deliver verification code")
)

// Service defines the interface for authentication operations.
type Service interface {
	SendRegistrationOTP(ctx context.Context, fullName, mobile, email string) error
	VerifyRegistrationMobile(ctx context.Context, mobile, otp, fullName, email string) (*VerifyMobileResult, error)
	VerifyRegistrationEmail(ctx context.Context, registrationToken, email, otp string) (*models.AuthResponse, error)
	SendLoginOTP(ctx context.Context, mobile string) error
	VerifyLoginOTP(ctx context.Context, mobile, otp string) (*models.AuthResponse, error)
	RefreshToken(ctx context.Context, rawRefreshToken string) (*models.AuthTokens, error)
	Logout(ctx context.Context, rawRefreshToken string) error
	GetCurrentUser(ctx context.Context, userID uuid.UUID) (*models.User, error)
}

// VerifyMobileResult holds the intermediate token returned after mobile verification.
type VerifyMobileResult struct {
	RegistrationToken string `json:"registration_token"`
	MobileVerified    bool   `json:"mobile_verified"`
	Message           string `json:"message"`
}

type authService struct {
	store       database.Store
	tokens      *TokenManager
	otpProvider *OTPProvider
	isDevMode   bool
}

// NewService creates a new authentication service.
func NewService(store database.Store, tokens *TokenManager, otpProvider *OTPProvider, isDevMode bool) Service {
	return &authService{
		store:       store,
		tokens:      tokens,
		otpProvider: otpProvider,
		isDevMode:   isDevMode,
	}
}

func (s *authService) SendRegistrationOTP(ctx context.Context, fullName, mobile, email string) error {
	validPhone, err := validator.ValidateAndFormatIndianPhone(mobile)
	if err != nil {
		return err
	}

	validName, err := validator.ValidateName(fullName)
	if err != nil {
		return err
	}

	var validEmail string
	if email != "" {
		validEmail, err = validator.ValidateEmail(email)
		if err != nil {
			return err
		}
	}

	// Check if already completed registration exists
	existingUser, err := s.store.Users().FindByPhone(ctx, validPhone)
	if err != nil && !errors.Is(err, database.ErrNotFound) {
		return fmt.Errorf("failed to query user by phone: %w", err)
	}
	if err == nil && existingUser != nil && existingUser.IsRegistrationComplete {
		return ErrUserAlreadyExists
	}

	if validEmail != "" {
		existingEmailUser, err := s.store.Users().FindByEmail(ctx, validEmail)
		if err != nil && !errors.Is(err, database.ErrNotFound) {
			return fmt.Errorf("failed to query user by email: %w", err)
		}
		if err == nil && existingEmailUser != nil && existingEmailUser.IsRegistrationComplete {
			return ErrUserAlreadyExists
		}
	}

	// Generate and hash OTP specifically for mobile registration
	otp, err := s.otpProvider.GenerateOTP(ctx, validPhone)
	if err != nil {
		return fmt.Errorf("failed to generate OTP: %w", err)
	}

	otpHash, err := s.otpProvider.HashOTP(otp)
	if err != nil {
		return fmt.Errorf("failed to hash OTP: %w", err)
	}

	// Temporary registration token
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return fmt.Errorf("failed to generate random token: %w", err)
	}
	rawToken := hex.EncodeToString(tokenBytes)
	tokenHash := HashToken(rawToken)

	// User provisioning: find or create uncompleted user
	var userID uuid.UUID
	if existingUser != nil {
		userID = existingUser.ID
		existingUser.FullName = validName
		if validEmail != "" {
			existingUser.Email = &validEmail
		}
		if err := s.store.Users().Update(ctx, existingUser); err != nil {
			return fmt.Errorf("failed to update user: %w", err)
		}
	} else {
		newUser := &models.User{
			ID:                     uuid.New(),
			Phone:                  validPhone,
			FullName:               validName,
			Role:                   models.RoleUser,
			IsRegistrationComplete: false,
		}
		if validEmail != "" {
			newUser.Email = &validEmail
		}
		if err := s.store.Users().Create(ctx, newUser); err != nil {
			return fmt.Errorf("failed to initialize user: %w", err)
		}
		userID = newUser.ID
	}

	pending := &models.PendingRegistration{
		ID:                    uuid.New(),
		UserID:                userID,
		MobileNumber:          validPhone,
		Email:                 validEmail,
		FullName:              validName,
		RegistrationTokenHash: tokenHash,
		IsMobileVerified:      false,
		IsEmailVerified:       false,
		ExpiresAt:             time.Now().UTC().Add(OTPExpiryDuration),
		CreatedAt:             time.Now().UTC(),
	}

	if err := s.store.PendingRegistrations().CreateOrReplace(ctx, pending); err != nil {
		return fmt.Errorf("failed to create pending registration: %w", err)
	}

	// Save isolated OTP challenge for mobile registration
	challenge := &models.OTPChallenge{
		ID:             uuid.New(),
		Destination:    validPhone,
		Purpose:        models.OTPPurposeMobileRegistration,
		OTPHash:        otpHash,
		FailedAttempts: 0,
		MaxAttempts:    MaxOTPAttempts,
		ExpiresAt:      time.Now().UTC().Add(OTPExpiryDuration),
		CreatedAt:      time.Now().UTC(),
	}

	if err := s.store.OTPChallenges().Create(ctx, challenge); err != nil {
		return fmt.Errorf("failed to save OTP challenge: %w", err)
	}

	// Dispatch SMS
	if err := s.otpProvider.SendSMS(ctx, validPhone, fmt.Sprintf("Your DODO Universe verification code is: %s", otp), otp); err != nil {
		return fmt.Errorf("%w: %v", ErrDeliveryFailed, err)
	}

	return nil
}

func (s *authService) VerifyRegistrationMobile(ctx context.Context, mobile, otp, fullName, email string) (*VerifyMobileResult, error) {
	validPhone, err := validator.ValidateAndFormatIndianPhone(mobile)
	if err != nil {
		return nil, err
	}

	validOTP, err := validator.ValidateOTP(otp)
	if err != nil {
		return nil, err
	}

	pending, err := s.store.PendingRegistrations().FindByMobile(ctx, validPhone)
	if err != nil {
		if errors.Is(err, database.ErrNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("failed to find pending registration: %w", err)
	}
	if pending == nil {
		return nil, ErrUserNotFound
	}

	if time.Now().UTC().After(pending.ExpiresAt) {
		return nil, ErrOTPExpired
	}

	// Retrieve isolated mobile registration OTP challenge
	challenge, err := s.store.OTPChallenges().FindLatestActive(ctx, models.OTPPurposeMobileRegistration, validPhone)
	if err != nil {
		if errors.Is(err, database.ErrNotFound) {
			return nil, ErrInvalidOTP
		}
		return nil, fmt.Errorf("failed to find OTP challenge: %w", err)
	}
	if challenge == nil || challenge.IsConsumed {
		return nil, ErrInvalidOTP
	}

	if time.Now().UTC().After(challenge.ExpiresAt) {
		return nil, ErrOTPExpired
	}

	if challenge.FailedAttempts >= challenge.MaxAttempts {
		_ = s.store.PendingRegistrations().Delete(ctx, pending.ID)
		return nil, ErrMaxAttemptsExceeded
	}

	// Verify OTP
	if !s.otpProvider.VerifyOTP(ctx, validPhone, validOTP, challenge.OTPHash) {
		attempts, _ := s.store.OTPChallenges().IncrementFailedAttempts(ctx, challenge.ID)
		if attempts >= challenge.MaxAttempts {
			_ = s.store.PendingRegistrations().Delete(ctx, pending.ID)
			return nil, ErrMaxAttemptsExceeded
		}
		return nil, ErrInvalidOTP
	}

	now := time.Now().UTC()
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return nil, fmt.Errorf("failed to generate registration token: %w", err)
	}
	rawRegistrationToken := hex.EncodeToString(tokenBytes)
	newTokenHash := HashToken(rawRegistrationToken)

	var emailToDispatch string
	var emailOTPToDispatch string

	// Perform state transition atomically
	err = s.store.WithTx(ctx, func(tx database.Store) error {
		// Conditionally mark challenge consumed
		if err := tx.OTPChallenges().MarkConsumed(ctx, challenge.ID, now); err != nil {
			if errors.Is(err, database.ErrChallengeAlreadyConsumed) {
				return ErrInvalidOTP
			}
			return fmt.Errorf("failed to consume challenge: %w", err)
		}

		if email != "" && pending.Email == "" {
			validEmail, err := validator.ValidateEmail(email)
			if err == nil {
				pending.Email = validEmail
			}
		}
		if fullName != "" && pending.FullName == "" {
			pending.FullName = fullName
		}

		pending.RegistrationTokenHash = newTokenHash
		pending.IsMobileVerified = true
		pending.ExpiresAt = now.Add(OTPExpiryDuration)
		if err := tx.PendingRegistrations().CreateOrReplace(ctx, pending); err != nil {
			return fmt.Errorf("failed to update pending registration: %w", err)
		}

		// Mark phone confirmed on user account
		user, err := tx.Users().FindByID(ctx, pending.UserID)
		if err != nil && !errors.Is(err, database.ErrNotFound) {
			return fmt.Errorf("failed to query user: %w", err)
		}
		if user != nil {
			user.PhoneConfirmedAt = &now
			if pending.Email != "" {
				user.Email = &pending.Email
			}
			if err := tx.Users().Update(ctx, user); err != nil {
				return fmt.Errorf("failed to update user phone confirmation: %w", err)
			}
		}

		// If pending email is available, prepare Step 3 Email OTP challenge
		if pending.Email != "" {
			emailOTP, err := s.otpProvider.GenerateOTP(ctx, pending.Email)
			if err != nil {
				return fmt.Errorf("failed to generate email OTP: %w", err)
			}
			emailOTPHash, err := s.otpProvider.HashOTP(emailOTP)
			if err != nil {
				return fmt.Errorf("failed to hash email OTP: %w", err)
			}

			emailChallenge := &models.OTPChallenge{
				ID:             uuid.New(),
				Destination:    pending.Email,
				Purpose:        models.OTPPurposeEmailRegistration,
				OTPHash:        emailOTPHash,
				FailedAttempts: 0,
				MaxAttempts:    MaxOTPAttempts,
				ExpiresAt:      now.Add(OTPExpiryDuration),
				CreatedAt:      now,
			}
			if err := tx.OTPChallenges().Create(ctx, emailChallenge); err != nil {
				return fmt.Errorf("failed to create email challenge: %w", err)
			}

			emailToDispatch = pending.Email
			emailOTPToDispatch = emailOTP
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	// Dispatch email OTP after successful transaction commit
	if emailToDispatch != "" && emailOTPToDispatch != "" {
		_ = s.otpProvider.SendEmail(ctx, emailToDispatch, "Verify your DODO Universe email", fmt.Sprintf("Your email verification code is: %s", emailOTPToDispatch), emailOTPToDispatch)
	}

	return &VerifyMobileResult{
		RegistrationToken: rawRegistrationToken,
		MobileVerified:    true,
		Message:           "Mobile verified successfully",
	}, nil
}

func (s *authService) VerifyRegistrationEmail(ctx context.Context, registrationToken, email, otp string) (*models.AuthResponse, error) {
	validEmail, err := validator.ValidateEmail(email)
	if err != nil {
		return nil, err
	}

	validOTP, err := validator.ValidateOTP(otp)
	if err != nil {
		return nil, err
	}

	if registrationToken == "" {
		return nil, errors.New("registration token is required")
	}

	tokenHash := HashToken(registrationToken)
	pending, err := s.store.PendingRegistrations().FindByTokenHash(ctx, tokenHash)
	if err != nil {
		if errors.Is(err, database.ErrNotFound) {
			return nil, ErrInvalidSession
		}
		return nil, fmt.Errorf("failed to find registration session: %w", err)
	}
	if pending == nil {
		return nil, ErrInvalidSession
	}

	if time.Now().UTC().After(pending.ExpiresAt) {
		return nil, ErrOTPExpired
	}

	if !pending.IsMobileVerified {
		return nil, ErrMobileNotVerified
	}

	// Email match validation
	if pending.Email == "" {
		pending.Email = validEmail
	} else if strings.ToLower(pending.Email) != strings.ToLower(validEmail) {
		return nil, ErrEmailMismatch
	}

	// Look up isolated email registration challenge
	challenge, err := s.store.OTPChallenges().FindLatestActive(ctx, models.OTPPurposeEmailRegistration, validEmail)
	if err != nil {
		if errors.Is(err, database.ErrNotFound) {
			return nil, ErrInvalidOTP
		}
		return nil, fmt.Errorf("failed to query email OTP challenge: %w", err)
	}
	if challenge == nil || challenge.IsConsumed {
		return nil, ErrInvalidOTP
	}

	if time.Now().UTC().After(challenge.ExpiresAt) {
		return nil, ErrOTPExpired
	}

	if challenge.FailedAttempts >= challenge.MaxAttempts {
		_ = s.store.PendingRegistrations().Delete(ctx, pending.ID)
		return nil, ErrMaxAttemptsExceeded
	}

	// Verify email OTP
	if !s.otpProvider.VerifyOTP(ctx, validEmail, validOTP, challenge.OTPHash) {
		attempts, _ := s.store.OTPChallenges().IncrementFailedAttempts(ctx, challenge.ID)
		if attempts >= challenge.MaxAttempts {
			_ = s.store.PendingRegistrations().Delete(ctx, pending.ID)
			return nil, ErrMaxAttemptsExceeded
		}
		return nil, ErrInvalidOTP
	}

	now := time.Now().UTC()
	var user *models.User
	var tokens *models.AuthTokens

	// Complete registration atomically
	err = s.store.WithTx(ctx, func(tx database.Store) error {
		// Conditionally mark challenge consumed
		if err := tx.OTPChallenges().MarkConsumed(ctx, challenge.ID, now); err != nil {
			if errors.Is(err, database.ErrChallengeAlreadyConsumed) {
				return ErrInvalidOTP
			}
			return fmt.Errorf("failed to consume email challenge: %w", err)
		}

		u, err := tx.Users().FindByID(ctx, pending.UserID)
		if err != nil {
			if errors.Is(err, database.ErrNotFound) {
				return ErrUserNotFound
			}
			return fmt.Errorf("failed to find user: %w", err)
		}
		if u == nil {
			return ErrUserNotFound
		}

		u.Email = &validEmail
		u.EmailConfirmedAt = &now
		u.IsRegistrationComplete = true
		u.UpdatedAt = now

		if err := tx.Users().Update(ctx, u); err != nil {
			return fmt.Errorf("failed to finalize user registration: %w", err)
		}

		// Invalidate pending registration
		if err := tx.PendingRegistrations().Delete(ctx, pending.ID); err != nil {
			return fmt.Errorf("failed to delete pending registration: %w", err)
		}

		// Issue genuine Auth tokens
		var session *models.Session
		tokens, session, err = s.tokens.CreateAuthTokens(u)
		if err != nil {
			return fmt.Errorf("failed to create tokens: %w", err)
		}

		if err := tx.Sessions().Create(ctx, session); err != nil {
			return fmt.Errorf("failed to persist session: %w", err)
		}

		user = u
		return nil
	})

	if err != nil {
		return nil, err
	}

	return &models.AuthResponse{
		User:   user,
		Tokens: tokens,
	}, nil
}

func (s *authService) SendLoginOTP(ctx context.Context, mobile string) error {
	validPhone, err := validator.ValidateAndFormatIndianPhone(mobile)
	if err != nil {
		return err
	}

	user, err := s.store.Users().FindByPhone(ctx, validPhone)
	if err != nil {
		if errors.Is(err, database.ErrNotFound) {
			return ErrUserNotFound
		}
		return fmt.Errorf("database query error: %w", err)
	}
	if user == nil || !user.IsRegistrationComplete {
		return ErrUserNotFound
	}

	otp, err := s.otpProvider.GenerateOTP(ctx, validPhone)
	if err != nil {
		return err
	}

	otpHash, err := s.otpProvider.HashOTP(otp)
	if err != nil {
		return err
	}

	// Save isolated login challenge (does not affect pending registrations)
	challenge := &models.OTPChallenge{
		ID:             uuid.New(),
		Destination:    validPhone,
		Purpose:        models.OTPPurposeLogin,
		OTPHash:        otpHash,
		FailedAttempts: 0,
		MaxAttempts:    MaxOTPAttempts,
		ExpiresAt:      time.Now().UTC().Add(OTPExpiryDuration),
		CreatedAt:      time.Now().UTC(),
	}

	if err := s.store.OTPChallenges().Create(ctx, challenge); err != nil {
		return fmt.Errorf("failed to create login OTP challenge: %w", err)
	}

	// Dispatch SMS
	if err := s.otpProvider.SendSMS(ctx, validPhone, fmt.Sprintf("Your DODO Universe login code is: %s", otp), otp); err != nil {
		return fmt.Errorf("%w: %v", ErrDeliveryFailed, err)
	}

	return nil
}

func (s *authService) VerifyLoginOTP(ctx context.Context, mobile, otp string) (*models.AuthResponse, error) {
	validPhone, err := validator.ValidateAndFormatIndianPhone(mobile)
	if err != nil {
		return nil, err
	}

	validOTP, err := validator.ValidateOTP(otp)
	if err != nil {
		return nil, err
	}

	user, err := s.store.Users().FindByPhone(ctx, validPhone)
	if err != nil {
		if errors.Is(err, database.ErrNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, fmt.Errorf("database error: %w", err)
	}
	if user == nil || !user.IsRegistrationComplete {
		return nil, ErrUserNotFound
	}

	challenge, err := s.store.OTPChallenges().FindLatestActive(ctx, models.OTPPurposeLogin, validPhone)
	if err != nil {
		if errors.Is(err, database.ErrNotFound) {
			return nil, ErrInvalidOTP
		}
		return nil, fmt.Errorf("database error: %w", err)
	}
	if challenge == nil || challenge.IsConsumed {
		return nil, ErrInvalidOTP
	}

	if time.Now().UTC().After(challenge.ExpiresAt) {
		return nil, ErrOTPExpired
	}

	if challenge.FailedAttempts >= challenge.MaxAttempts {
		return nil, ErrMaxAttemptsExceeded
	}

	if !s.otpProvider.VerifyOTP(ctx, validPhone, validOTP, challenge.OTPHash) {
		attempts, _ := s.store.OTPChallenges().IncrementFailedAttempts(ctx, challenge.ID)
		if attempts >= challenge.MaxAttempts {
			return nil, ErrMaxAttemptsExceeded
		}
		return nil, ErrInvalidOTP
	}

	now := time.Now().UTC()
	var tokens *models.AuthTokens
	err = s.store.WithTx(ctx, func(tx database.Store) error {
		// Conditionally mark challenge consumed
		if err := tx.OTPChallenges().MarkConsumed(ctx, challenge.ID, now); err != nil {
			if errors.Is(err, database.ErrChallengeAlreadyConsumed) {
				return ErrInvalidOTP
			}
			return fmt.Errorf("failed to mark challenge consumed: %w", err)
		}

		var session *models.Session
		var err error
		tokens, session, err = s.tokens.CreateAuthTokens(user)
		if err != nil {
			return err
		}
		return tx.Sessions().Create(ctx, session)
	})

	if err != nil {
		return nil, fmt.Errorf("failed to persist login session: %w", err)
	}

	return &models.AuthResponse{
		User:   user,
		Tokens: tokens,
	}, nil
}

func (s *authService) RefreshToken(ctx context.Context, rawRefreshToken string) (*models.AuthTokens, error) {
	if rawRefreshToken == "" {
		return nil, ErrUnauthorized
	}

	tokenHash := HashToken(rawRefreshToken)
	var tokens *models.AuthTokens

	// Refresh token rotation in transaction with conditional revocation
	err := s.store.WithTx(ctx, func(tx database.Store) error {
		session, err := tx.Sessions().FindByTokenHash(ctx, tokenHash)
		if err != nil {
			if errors.Is(err, database.ErrNotFound) {
				return ErrUnauthorized
			}
			return fmt.Errorf("database query error: %w", err)
		}
		if session == nil || session.RevokedAt != nil {
			return ErrUnauthorized
		}

		if time.Now().UTC().After(session.ExpiresAt) {
			_ = tx.Sessions().Revoke(ctx, session.ID)
			return ErrUnauthorized
		}

		// Conditional atomic revocation
		if err := tx.Sessions().Revoke(ctx, session.ID); err != nil {
			if errors.Is(err, database.ErrSessionAlreadyRevoked) {
				return ErrUnauthorized
			}
			return fmt.Errorf("failed to revoke session: %w", err)
		}

		user, err := tx.Users().FindByID(ctx, session.UserID)
		if err != nil {
			if errors.Is(err, database.ErrNotFound) {
				return ErrUserNotFound
			}
			return fmt.Errorf("failed to find user: %w", err)
		}
		if user == nil {
			return ErrUserNotFound
		}

		var newSession *models.Session
		tokens, newSession, err = s.tokens.CreateAuthTokens(user)
		if err != nil {
			return fmt.Errorf("failed to create tokens: %w", err)
		}

		return tx.Sessions().Create(ctx, newSession)
	})

	if err != nil {
		return nil, err
	}

	return tokens, nil
}

func (s *authService) Logout(ctx context.Context, rawRefreshToken string) error {
	if rawRefreshToken == "" {
		return nil
	}
	tokenHash := HashToken(rawRefreshToken)
	session, err := s.store.Sessions().FindByTokenHash(ctx, tokenHash)
	if err == nil && session != nil {
		return s.store.Sessions().Revoke(ctx, session.ID)
	}
	return nil
}

func (s *authService) GetCurrentUser(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	return s.store.Users().FindByID(ctx, userID)
}
