package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"dodo-universe-backend/internal/models"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// TokenManager handles generation and validation of access and refresh tokens.
type TokenManager struct {
	secret            []byte
	jwtExpiryMinutes  int
	refreshExpiryDays int
}

// NewTokenManager initializes a TokenManager.
func NewTokenManager(secret string, jwtExpiryMinutes, refreshExpiryDays int) *TokenManager {
	return &TokenManager{
		secret:            []byte(secret),
		jwtExpiryMinutes:  jwtExpiryMinutes,
		refreshExpiryDays: refreshExpiryDays,
	}
}

// GenerateAccessToken signs a new JWT with user claims.
func (tm *TokenManager) GenerateAccessToken(user *models.User) (string, error) {
	now := time.Now().UTC()
	expiresAt := now.Add(time.Duration(tm.jwtExpiryMinutes) * time.Minute)

	email := ""
	if user.Email != nil {
		email = *user.Email
	}

	claims := &models.UserClaims{
		UserID:   user.ID.String(),
		Phone:    user.Phone,
		Email:    email,
		FullName: user.FullName,
		Role:     user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   user.ID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			Issuer:    "dodo-universe-backend",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(tm.secret)
}

// GenerateRefreshToken generates a secure 64-character random hex string and its SHA-256 hash.
func (tm *TokenManager) GenerateRefreshToken(userID uuid.UUID) (*models.Session, string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return nil, "", fmt.Errorf("failed to generate random bytes: %w", err)
	}

	rawToken := hex.EncodeToString(bytes)
	tokenHash := HashToken(rawToken)

	now := time.Now().UTC()
	expiresAt := now.AddDate(0, 0, tm.refreshExpiryDays)

	session := &models.Session{
		ID:        uuid.New(),
		UserID:    userID,
		TokenHash: tokenHash,
		ExpiresAt: expiresAt,
		CreatedAt: now,
	}

	return session, rawToken, nil
}

// HashToken generates a SHA-256 hash of a string.
func HashToken(rawToken string) string {
	h := sha256.Sum256([]byte(rawToken))
	return hex.EncodeToString(h[:])
}

// CreateAuthTokens creates both access and refresh tokens for a user.
func (tm *TokenManager) CreateAuthTokens(user *models.User) (*models.AuthTokens, *models.Session, error) {
	accessToken, err := tm.GenerateAccessToken(user)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	session, rawRefreshToken, err := tm.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	return &models.AuthTokens{
		AccessToken:  accessToken,
		RefreshToken: rawRefreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    int64(tm.jwtExpiryMinutes * 60),
	}, session, nil
}

