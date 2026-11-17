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
