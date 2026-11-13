package auth

import (
	"encoding/json"
	"net/http"

	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/pkg/response"
	"github.com/google/uuid"
)

// Handler handles HTTP requests for authentication.
type Handler struct {
	service Service
}

// NewHandler creates a new auth HTTP handler.
func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers the auth routes onto an http.ServeMux.
func (h *Handler) RegisterRoutes(mux *http.ServeMux, authMiddleware func(http.Handler) http.Handler) {
	mux.HandleFunc("POST /api/v1/auth/register/send-otp", h.HandleSendRegistrationOTP)
	mux.HandleFunc("POST /api/v1/auth/register/verify-mobile", h.HandleVerifyRegistrationMobile)
	mux.HandleFunc("POST /api/v1/auth/register/verify-email", h.HandleVerifyRegistrationEmail)
	mux.HandleFunc("POST /api/v1/auth/login/send-otp", h.HandleSendLoginOTP)
	mux.HandleFunc("POST /api/v1/auth/login/verify-otp", h.HandleVerifyLoginOTP)
	mux.HandleFunc("POST /api/v1/auth/refresh", h.HandleRefreshToken)
	mux.HandleFunc("POST /api/v1/auth/logout", h.HandleLogout)

	// Protected route
	mux.Handle("GET /api/v1/auth/me", authMiddleware(http.HandlerFunc(h.HandleGetMe)))
}

type sendRegistrationOTPRequest struct {
	FullName string `json:"full_name"`
	Mobile   string `json:"mobile_number"`
	Email    string `json:"email,omitempty"`
}

func (h *Handler) HandleSendRegistrationOTP(w http.ResponseWriter, r *http.Request) {
	var req sendRegistrationOTPRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON request payload")
		return
	}

	if err := h.service.SendRegistrationOTP(r.Context(), req.FullName, req.Mobile, req.Email); err != nil {
		if errorsIs(err, ErrUserAlreadyExists) {
			response.BadRequest(w, "An account with this mobile number or email already exists. Please login.", "USER_EXISTS")
			return
		}
		response.BadRequest(w, err.Error())
		return
	}

	response.OK(w, map[string]string{
		"message": "OTP sent successfully",
	})
}

type verifyMobileRequest struct {
	Mobile   string `json:"mobile_number"`
	OTP      string `json:"otp"`
	FullName string `json:"full_name,omitempty"`
	Email    string `json:"email,omitempty"`
}

func (h *Handler) HandleVerifyRegistrationMobile(w http.ResponseWriter, r *http.Request) {
	var req verifyMobileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON request payload")
		return
	}

	result, err := h.service.VerifyRegistrationMobile(r.Context(), req.Mobile, req.OTP, req.FullName, req.Email)
	if err != nil {
		switch {
		case errorsIs(err, ErrInvalidOTP):
			response.BadRequest(w, "Invalid OTP code. Please enter the correct code.", "INVALID_OTP")
		case errorsIs(err, ErrOTPExpired):
			response.BadRequest(w, "Registration session has expired. Please restart registration.", "EXPIRED_OTP")
		case errorsIs(err, ErrMaxAttemptsExceeded):
			response.Error(w, http.StatusTooManyRequests, "MAX_ATTEMPTS", "Too many failed attempts. Account locked for 15 minutes.")
		default:
			response.BadRequest(w, err.Error())
		}
		return
	}

	response.OK(w, result)
}

type verifyEmailRequest struct {
	RegistrationToken string `json:"registration_token"`
	Email             string `json:"email"`
	OTP               string `json:"otp"`
}

func (h *Handler) HandleVerifyRegistrationEmail(w http.ResponseWriter, r *http.Request) {
	var req verifyEmailRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON request payload")
		return
	}

	result, err := h.service.VerifyRegistrationEmail(r.Context(), req.RegistrationToken, req.Email, req.OTP)
	if err != nil {
		switch {
		case errorsIs(err, ErrInvalidOTP):
			response.BadRequest(w, "Invalid or expired OTP. Please try again.", "INVALID_OTP")
		case errorsIs(err, ErrOTPExpired):
			response.BadRequest(w, "Registration session has expired. Please restart registration.", "EXPIRED_OTP")
		case errorsIs(err, ErrMaxAttemptsExceeded):
			response.Error(w, http.StatusTooManyRequests, "MAX_ATTEMPTS", "Too many failed attempts. Registration session invalidated.")
		case errorsIs(err, ErrMobileNotVerified):
			response.BadRequest(w, "Mobile number must be verified before email.", "MOBILE_NOT_VERIFIED")
		case errorsIs(err, ErrEmailMismatch):
			response.BadRequest(w, "Email does not match registration session.", "EMAIL_MISMATCH")
		default:
			response.BadRequest(w, err.Error())
		}
		return
	}

	response.OK(w, result, "Registration completed successfully")
}

type sendLoginOTPRequest struct {
	Mobile string `json:"mobile_number"`
}

func (h *Handler) HandleSendLoginOTP(w http.ResponseWriter, r *http.Request) {
	var req sendLoginOTPRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON request payload")
		return
	}

	if err := h.service.SendLoginOTP(r.Context(), req.Mobile); err != nil {
		if errorsIs(err, ErrUserNotFound) {
			response.NotFound(w, "No existing account found with this mobile number. Please register first.", "USER_NOT_FOUND")
			return
		}
		response.BadRequest(w, err.Error())
		return
	}

	response.OK(w, map[string]string{
		"message": "Login OTP ready",
	})
}

type verifyLoginOTPRequest struct {
	Mobile string `json:"mobile_number"`
	OTP    string `json:"otp"`
}

func (h *Handler) HandleVerifyLoginOTP(w http.ResponseWriter, r *http.Request) {
	var req verifyLoginOTPRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON request payload")
		return
	}

	result, err := h.service.VerifyLoginOTP(r.Context(), req.Mobile, req.OTP)
	if err != nil {
		switch {
		case errorsIs(err, ErrInvalidOTP):
			response.BadRequest(w, "Invalid verification code.", "INVALID_OTP")
		case errorsIs(err, ErrUserNotFound):
			response.NotFound(w, "User account not found.", "USER_NOT_FOUND")
		default:
			response.BadRequest(w, err.Error())
		}
		return
	}

	response.OK(w, result, "Login successful")
}

type refreshTokenRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) HandleRefreshToken(w http.ResponseWriter, r *http.Request) {
	var req refreshTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.BadRequest(w, "Invalid JSON request payload")
		return
	}

	tokens, err := h.service.RefreshToken(r.Context(), req.RefreshToken)
	if err != nil {
		response.Unauthorized(w, "Invalid or expired refresh token")
		return
	}

	response.OK(w, tokens)
}

type logoutRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) HandleLogout(w http.ResponseWriter, r *http.Request) {
	var req logoutRequest
	_ = json.NewDecoder(r.Body).Decode(&req)

	_ = h.service.Logout(r.Context(), req.RefreshToken)
	response.OK(w, map[string]string{"message": "Logged out successfully"})
}

func (h *Handler) HandleGetMe(w http.ResponseWriter, r *http.Request) {
	claims, ok := middleware.GetClaims(r)
	if !ok || claims == nil {
		response.Unauthorized(w, "Unauthorized")
		return
	}

	uid, err := uuid.Parse(claims.UserID)
	if err != nil {
		response.Unauthorized(w, "Invalid user identifier in token")
		return
	}

	user, err := h.service.GetCurrentUser(r.Context(), uid)
	if err != nil || user == nil {
		response.NotFound(w, "User not found")
		return
	}

	response.OK(w, user)
}

func errorsIs(err, target error) bool {
	return err == target || (err != nil && target != nil && err.Error() == target.Error())
}

