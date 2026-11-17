package auth_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"dodo-universe-backend/internal/auth"
	"dodo-universe-backend/internal/database"
	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/internal/models"
	"github.com/google/uuid"
)

type failingSMSProvider struct{}

func (f *failingSMSProvider) SendSMS(ctx context.Context, to, message string) error {
	return errors.New("simulated SMS network outage")
}

func setupTestEnvironment() (*http.ServeMux, auth.Service, database.Store, *auth.InMemDeliveryRecorder) {
	store := database.NewMemoryStore()
	tokenManager := auth.NewTokenManager("test-jwt-secret-key-1234567890123456", 60, 30)
	recorder := auth.NewInMemDeliveryRecorder()
	otpProvider := auth.NewOTPProvider(true, "123456", store.DevTestNumbers(), nil, nil, recorder)
	authSvc := auth.NewService(store, tokenManager, otpProvider, true)
	authMiddleware := middleware.Authenticate("test-jwt-secret-key-1234567890123456")

	mux := http.NewServeMux()
	handler := auth.NewHandler(authSvc)
	handler.RegisterRoutes(mux, authMiddleware)

	return mux, authSvc, store, recorder
}

func TestAuthFlow_FullRegistrationAndLogin(t *testing.T) {
	mux, _, _, _ := setupTestEnvironment()

	// 1. Send Registration OTP
	sendPayload := map[string]string{
		"full_name":     "Yamini Sharma",
		"mobile_number": "9876543210",
		"email":         "yamini@example.com",
	}
	body, _ := json.Marshal(sendPayload)
	req := httptest.NewRequest("POST", "/api/v1/auth/register/send-otp", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 on send-otp, got %d: %s", w.Code, w.Body.String())
	}

	// 2. Verify Mobile OTP (Enter dev OTP 123456)
	verifyMobilePayload := map[string]string{
		"mobile_number": "9876543210",
		"otp":           "123456",
		"full_name":     "Yamini Sharma",
		"email":         "yamini@example.com",
	}
	body, _ = json.Marshal(verifyMobilePayload)
	req = httptest.NewRequest("POST", "/api/v1/auth/register/verify-mobile", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 on verify-mobile, got %d: %s", w.Code, w.Body.String())
	}

	var mobileResp struct {
		Success bool                    `json:"success"`
		Data    auth.VerifyMobileResult `json:"data"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &mobileResp)

	regToken := mobileResp.Data.RegistrationToken
	if regToken == "" {
		t.Fatalf("expected non-empty registration_token, got empty")
	}

	// 3. Verify Email OTP (Enter dev OTP 123456)
	verifyEmailPayload := map[string]string{
		"registration_token": regToken,
		"email":              "yamini@example.com",
		"otp":                "123456",
	}
	body, _ = json.Marshal(verifyEmailPayload)
	req = httptest.NewRequest("POST", "/api/v1/auth/register/verify-email", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 on verify-email, got %d: %s", w.Code, w.Body.String())
	}

	var authResp struct {
		Success bool                `json:"success"`
		Data    models.AuthResponse `json:"data"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &authResp)

	if authResp.Data.User == nil || !authResp.Data.User.IsRegistrationComplete {
		t.Fatalf("expected registration to be complete, got %+v", authResp.Data.User)
	}
	if authResp.Data.Tokens == nil || authResp.Data.Tokens.AccessToken == "" {
		t.Fatalf("expected valid access_token, got empty")
	}

	accessToken := authResp.Data.Tokens.AccessToken
	refreshToken := authResp.Data.Tokens.RefreshToken

	// 4. Test Protected Route (/api/v1/auth/me) with Access Token
	req = httptest.NewRequest("GET", "/api/v1/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 on /api/v1/auth/me, got %d: %s", w.Code, w.Body.String())
	}

	// 5. Test Refresh Token
	refreshPayload := map[string]string{
		"refresh_token": refreshToken,
	}
	body, _ = json.Marshal(refreshPayload)
	req = httptest.NewRequest("POST", "/api/v1/auth/refresh", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 on /api/v1/auth/refresh, got %d: %s", w.Code, w.Body.String())
	}

	var refreshResp struct {
		Success bool              `json:"success"`
		Data    models.AuthTokens `json:"data"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &refreshResp)
	newRefreshToken := refreshResp.Data.RefreshToken

	// 6. Test Returning User Login Flow
	loginReqPayload := map[string]string{
		"mobile_number": "9876543210",
	}
	body, _ = json.Marshal(loginReqPayload)
	req = httptest.NewRequest("POST", "/api/v1/auth/login/send-otp", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 on login send-otp, got %d: %s", w.Code, w.Body.String())
	}

	verifyLoginPayload := map[string]string{
		"mobile_number": "9876543210",
		"otp":           "123456",
	}
	body, _ = json.Marshal(verifyLoginPayload)
	req = httptest.NewRequest("POST", "/api/v1/auth/login/verify-otp", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 on login verify-otp, got %d: %s", w.Code, w.Body.String())
	}

	// 7. Test Logout with newest refresh token
	logoutPayload := map[string]string{
		"refresh_token": newRefreshToken,
	}
	body, _ = json.Marshal(logoutPayload)
	req = httptest.NewRequest("POST", "/api/v1/auth/logout", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200 on logout, got %d", w.Code)
	}
}

func TestMemoryStore_DeadlockPreventionAndRollback(t *testing.T) {
	store := database.NewMemoryStore()
	ctx := context.Background()

	// 1. Verify nested operations inside WithTx do NOT deadlock
	user := &models.User{
		ID:       uuid.New(),
		Phone:    "+919876543211",
		FullName: "Tx User",
		Role:     models.RoleUser,
	}

	err := store.WithTx(ctx, func(tx database.Store) error {
		// Inside transaction: create user and query it immediately
		if err := tx.Users().Create(ctx, user); err != nil {
			return err
		}
		found, err := tx.Users().FindByID(ctx, user.ID)
		if err != nil || found == nil {
			return errors.New("expected user to be visible inside tx")
		}
		return nil
	})
	if err != nil {
		t.Fatalf("WithTx returned error: %v", err)
	}

	// User should exist after commit
	saved, err := store.Users().FindByID(ctx, user.ID)
	if err != nil || saved == nil {
		t.Fatalf("expected user to exist after commit")
	}

	// 2. Verify rollback on error
	rollbackUser := &models.User{
		ID:       uuid.New(),
		Phone:    "+919876543212",
		FullName: "Rollback User",
		Role:     models.RoleUser,
	}

	err = store.WithTx(ctx, func(tx database.Store) error {
		if err := tx.Users().Create(ctx, rollbackUser); err != nil {
			return err
		}
		return errors.New("forced rollback")
	})
	if err == nil {
		t.Fatalf("expected error from WithTx")
	}

	// Rollback user MUST NOT exist in store
	rolledBack, err := store.Users().FindByID(ctx, rollbackUser.ID)
	if err == nil || rolledBack != nil {
		t.Fatalf("expected rollback user to NOT exist in store after aborted transaction")
	}
}

func TestAuth_ConcurrentOTPVerification(t *testing.T) {
	_, authSvc, _, _ := setupTestEnvironment()
	ctx := context.Background()

	phone := "9876543220"
	err := authSvc.SendRegistrationOTP(ctx, "Concurrent User", phone, "concurrent@example.com")
	if err != nil {
		t.Fatalf("failed to send OTP: %v", err)
	}

	// Spawn 5 concurrent verification attempts with the same OTP
	concurrency := 5
	var successCount int32
	var failCount int32
	var wg sync.WaitGroup

	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := authSvc.VerifyRegistrationMobile(ctx, phone, "123456", "Concurrent User", "concurrent@example.com")
			if err == nil {
				atomic.AddInt32(&successCount, 1)
			} else {
				atomic.AddInt32(&failCount, 1)
			}
		}()
	}
	wg.Wait()

	// Exactly ONE concurrent request should succeed; others must be rejected
	if successCount != 1 {
		t.Fatalf("expected exactly 1 verification to succeed, got %d successes and %d failures", successCount, failCount)
	}
}

func TestAuth_ConcurrentRefreshTokenRotation(t *testing.T) {
	_, authSvc, _, _ := setupTestEnvironment()
	ctx := context.Background()

	// Register user
	phone := "9876543230"
	_ = authSvc.SendRegistrationOTP(ctx, "Rotate Race User", phone, "race@example.com")
	res, _ := authSvc.VerifyRegistrationMobile(ctx, phone, "123456", "Rotate Race User", "race@example.com")
	authResp, err := authSvc.VerifyRegistrationEmail(ctx, res.RegistrationToken, "race@example.com", "123456")
	if err != nil {
		t.Fatalf("registration failed: %v", err)
	}

	originalRefreshToken := authResp.Tokens.RefreshToken

	// Attempt 5 concurrent rotations with the exact same refresh token
	concurrency := 5
	var successCount int32
	var failCount int32
	var wg sync.WaitGroup

	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := authSvc.RefreshToken(ctx, originalRefreshToken)
			if err == nil {
				atomic.AddInt32(&successCount, 1)
			} else {
				atomic.AddInt32(&failCount, 1)
			}
		}()
	}
	wg.Wait()

	// Exactly ONE rotation must succeed; other 4 must receive ErrUnauthorized
	if successCount != 1 {
		t.Fatalf("expected exactly 1 rotation to succeed, got %d successes and %d failures", successCount, failCount)
	}
}

func TestAuth_RollbackAfterRegistrationFailure(t *testing.T) {
	_, authSvc, store, _ := setupTestEnvironment()
	ctx := context.Background()

	phone := "9876543240"
	_ = authSvc.SendRegistrationOTP(ctx, "Fail User", phone, "fail@example.com")
	res, _ := authSvc.VerifyRegistrationMobile(ctx, phone, "123456", "Fail User", "fail@example.com")

	// Verify email with WRONG OTP -> must fail and leave user uncompleted
	_, err := authSvc.VerifyRegistrationEmail(ctx, res.RegistrationToken, "fail@example.com", "999999")
	if err == nil {
		t.Fatalf("expected error on wrong OTP")
	}

	// Verify user is NOT complete
	user, err := store.Users().FindByPhone(ctx, "+91"+phone)
	if err != nil || user == nil {
		t.Fatalf("expected user to exist")
	}
	if user.IsRegistrationComplete {
		t.Fatalf("expected IsRegistrationComplete to be false after failed verification")
	}
}

func TestAuth_OTPDeliveryFailure(t *testing.T) {
	store := database.NewMemoryStore()
	tokenManager := auth.NewTokenManager("test-jwt-secret-key-1234567890123456", 60, 30)
	failingSMS := &failingSMSProvider{}
	otpProvider := auth.NewOTPProvider(false, "", nil, failingSMS, nil, nil)
	authSvc := auth.NewService(store, tokenManager, otpProvider, false)

	ctx := context.Background()
	// Attempt sending OTP with broken SMS provider
	err := authSvc.SendRegistrationOTP(ctx, "Network User", "9876543250", "net@example.com")
	if err == nil {
		t.Fatalf("expected error when SMS provider fails")
	}
	if !errors.Is(err, auth.ErrDeliveryFailed) {
		t.Fatalf("expected ErrDeliveryFailed, got: %v", err)
	}
}

func TestAuth_LegacySupabaseUserPreservation(t *testing.T) {
	store := database.NewMemoryStore()
	ctx := context.Background()

	// Existing user created in Supabase with email only (phone is null/empty)
	legacyUser := &models.User{
		ID:                     uuid.New(),
		Phone:                  "", // No phone
		Email:                  strPtr("legacy@supabase.co"),
		FullName:               "Legacy Supabase User",
		Role:                   models.RoleUser,
		IsRegistrationComplete: false,
		CreatedAt:              time.Now().UTC().AddDate(0, -1, 0),
		UpdatedAt:              time.Now().UTC().AddDate(0, -1, 0),
	}
	err := store.Users().Create(ctx, legacyUser)
	if err != nil {
		t.Fatalf("failed to create legacy user: %v", err)
	}

	// Query by email should succeed without phone error
	found, err := store.Users().FindByEmail(ctx, "legacy@supabase.co")
	if err != nil || found == nil {
		t.Fatalf("expected to find legacy user by email, got %v", err)
	}
	if found.ID != legacyUser.ID {
		t.Fatalf("expected ID %v, got %v", legacyUser.ID, found.ID)
	}
	if found.Phone != "" {
		t.Fatalf("expected phone to be empty, got: %s", found.Phone)
	}
}

func strPtr(s string) *string {
	return &s
}
