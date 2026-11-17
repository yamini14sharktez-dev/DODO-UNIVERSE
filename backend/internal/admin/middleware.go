package admin

import (
	"context"
	"net/http"
	"strings"

	"dodo-universe-backend/internal/models"
	"dodo-universe-backend/pkg/response"
	"github.com/golang-jwt/jwt/v5"
)

type adminContextKey string

const (
	adminClaimsKey adminContextKey = "admin_claims"
)

// Authenticate verifies the Bearer JWT token in the Authorization header against Admin claims.
func Authenticate(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				response.Unauthorized(w, "Missing Authorization header")
				return
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
				response.Unauthorized(w, "Invalid Authorization header format. Expected Bearer <token>")
				return
			}

			tokenString := parts[1]
			claims := &models.AdminClaims{}

			token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
				if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, jwt.ErrSignatureInvalid
				}
				return []byte(jwtSecret), nil
			})

			if err != nil || !token.Valid {
				response.Unauthorized(w, "Invalid or expired admin access token")
				return
			}

			ctx := context.WithValue(r.Context(), adminClaimsKey, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// GetAdminClaims extracts the authenticated AdminClaims from request context.
func GetAdminClaims(r *http.Request) (*models.AdminClaims, bool) {
	claims, ok := r.Context().Value(adminClaimsKey).(*models.AdminClaims)
	return claims, ok
}

// RequireRole ensures the authenticated administrator possesses one of the allowed roles.
func RequireRole(allowedRoles ...models.AdminRole) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := GetAdminClaims(r)
			if !ok {
				response.Unauthorized(w, "Unauthorized")
				return
			}

			for _, role := range allowedRoles {
				if claims.Role == role {
					next.ServeHTTP(w, r)
					return
				}
			}

			response.Forbidden(w, "Insufficient administrative privileges for this operation")
		})
	}
}
