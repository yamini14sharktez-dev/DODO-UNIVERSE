package database

import (
	"context"
	"strings"
	"sync"
	"time"

	"dodo-universe-backend/internal/models"
	"github.com/google/uuid"
)

// MemoryStore provides a concurrency-safe in-memory Store implementation.
type MemoryStore struct {
	mu                   sync.RWMutex
	users                map[uuid.UUID]*models.User
	pendingRegistrations map[uuid.UUID]*models.PendingRegistration
	otpChallenges        map[uuid.UUID]*models.OTPChallenge
	sessions             map[uuid.UUID]*models.Session
	devTestNumbers       map[string]*models.DevTestNumber
}

// NewMemoryStore initializes a new thread-safe in-memory database store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		users:                make(map[uuid.UUID]*models.User),
		pendingRegistrations: make(map[uuid.UUID]*models.PendingRegistration),
		otpChallenges:        make(map[uuid.UUID]*models.OTPChallenge),
		sessions:             make(map[uuid.UUID]*models.Session),
		devTestNumbers:       make(map[string]*models.DevTestNumber),
	}
}

func (m *MemoryStore) Users() UserRepository {
	return &memoryUserRepo{store: m}
}

func (m *MemoryStore) PendingRegistrations() PendingRegistrationRepository {
	return &memoryPendingRepo{store: m}
}

func (m *MemoryStore) OTPChallenges() OTPChallengeRepository {
	return &memoryOTPRepo{store: m}
}

func (m *MemoryStore) Sessions() SessionRepository {
	return &memorySessionRepo{store: m}
}

func (m *MemoryStore) DevTestNumbers() DevTestNumberRepository {
	return &memoryDevNumberRepo{store: m}
}

// WithTx executes fn inside an isolated memory transaction.
// It snapshots state under a read lock, executes fn without holding parent locks (preventing deadlocks),
// and atomically commits state on success, or discards the snapshot on error.
func (m *MemoryStore) WithTx(ctx context.Context, fn func(tx Store) error) error {
	m.mu.RLock()
	txStore := &memoryTxStore{
		parent:               m,
		users:                cloneUserMap(m.users),
		pendingRegistrations: clonePendingMap(m.pendingRegistrations),
		otpChallenges:        cloneChallengeMap(m.otpChallenges),
		sessions:             cloneSessionMap(m.sessions),
		devTestNumbers:       cloneDevNumberMap(m.devTestNumbers),
	}
	m.mu.RUnlock()

	if err := fn(txStore); err != nil {
		// Rollback: snapshot is discarded
		return err
	}

	// Commit snapshot atomically under write lock
	m.mu.Lock()
	defer m.mu.Unlock()
	m.users = txStore.users
	m.pendingRegistrations = txStore.pendingRegistrations
	m.otpChallenges = txStore.otpChallenges
	m.sessions = txStore.sessions
	m.devTestNumbers = txStore.devTestNumbers

	return nil
}

func (m *MemoryStore) Close() error {
	return nil
}

func (m *MemoryStore) Ping(ctx context.Context) error {
	return nil
}

// -----------------------------------------------------------------------------
// Transactional Snapshot Store
// -----------------------------------------------------------------------------
type memoryTxStore struct {
	parent               *MemoryStore
	mu                   sync.RWMutex
	users                map[uuid.UUID]*models.User
	pendingRegistrations map[uuid.UUID]*models.PendingRegistration
	otpChallenges        map[uuid.UUID]*models.OTPChallenge
	sessions             map[uuid.UUID]*models.Session
	devTestNumbers       map[string]*models.DevTestNumber
}

func (t *memoryTxStore) Users() UserRepository {
	return &memoryTxUserRepo{tx: t}
}

func (t *memoryTxStore) PendingRegistrations() PendingRegistrationRepository {
	return &memoryTxPendingRepo{tx: t}
}

func (t *memoryTxStore) OTPChallenges() OTPChallengeRepository {
	return &memoryTxOTPRepo{tx: t}
}

func (t *memoryTxStore) Sessions() SessionRepository {
	return &memoryTxSessionRepo{tx: t}
}

func (t *memoryTxStore) DevTestNumbers() DevTestNumberRepository {
	return &memoryTxDevNumberRepo{tx: t}
}

func (t *memoryTxStore) WithTx(ctx context.Context, fn func(tx Store) error) error {
	// Nested transaction operates within the same snapshot
	return fn(t)
}

func (t *memoryTxStore) Close() error {
	return nil
}

func (t *memoryTxStore) Ping(ctx context.Context) error {
	return nil
}

// -----------------------------------------------------------------------------
// Users Repositories
// -----------------------------------------------------------------------------
type memoryUserRepo struct {
	store *MemoryStore
}

func (r *memoryUserRepo) FindByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()

	user, ok := r.store.users[id]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneUser(user), nil
}

func (r *memoryUserRepo) FindByPhone(ctx context.Context, phone string) (*models.User, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()

	targetDigits := extractDigits(phone)
	if len(targetDigits) < 10 {
		return nil, ErrNotFound
	}
	target10 := targetDigits[len(targetDigits)-10:]

	for _, user := range r.store.users {
		uDigits := extractDigits(user.Phone)
		if len(uDigits) >= 10 && uDigits[len(uDigits)-10:] == target10 {
			return cloneUser(user), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryUserRepo) FindByEmail(ctx context.Context, email string) (*models.User, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()

	normalized := strings.ToLower(strings.TrimSpace(email))
	if normalized == "" {
		return nil, ErrNotFound
	}

	for _, user := range r.store.users {
		if user.Email != nil && strings.ToLower(strings.TrimSpace(*user.Email)) == normalized {
			return cloneUser(user), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryUserRepo) Create(ctx context.Context, user *models.User) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	targetDigits := extractDigits(user.Phone)
	if len(targetDigits) >= 10 {
		target10 := targetDigits[len(targetDigits)-10:]
		for _, existing := range r.store.users {
			eDigits := extractDigits(existing.Phone)
			if len(eDigits) >= 10 && eDigits[len(eDigits)-10:] == target10 {
				return ErrAlreadyExists
			}
		}
	}

	if user.Email != nil && strings.TrimSpace(*user.Email) != "" {
		targetEmail := strings.ToLower(strings.TrimSpace(*user.Email))
		for _, existing := range r.store.users {
			if existing.Email != nil && strings.ToLower(strings.TrimSpace(*existing.Email)) == targetEmail {
				return ErrAlreadyExists
			}
		}
	}

	if user.ID == uuid.Nil {
		user.ID = uuid.New()
	}
	now := time.Now().UTC()
	user.CreatedAt = now
	user.UpdatedAt = now

	r.store.users[user.ID] = cloneUser(user)
	return nil
}

func (r *memoryUserRepo) Update(ctx context.Context, user *models.User) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	existing, ok := r.store.users[user.ID]
	if !ok {
		return ErrNotFound
	}

	targetDigits := extractDigits(user.Phone)
	if len(targetDigits) >= 10 {
		target10 := targetDigits[len(targetDigits)-10:]
		for id, other := range r.store.users {
			if id != user.ID {
				oDigits := extractDigits(other.Phone)
				if len(oDigits) >= 10 && oDigits[len(oDigits)-10:] == target10 {
					return ErrAlreadyExists
				}
			}
		}
	}

	user.UpdatedAt = time.Now().UTC()
	user.CreatedAt = existing.CreatedAt

	r.store.users[user.ID] = cloneUser(user)
	return nil
}

// Transactional User Repo
type memoryTxUserRepo struct {
	tx *memoryTxStore
}

func (r *memoryTxUserRepo) FindByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	r.tx.mu.RLock()
	defer r.tx.mu.RUnlock()

	user, ok := r.tx.users[id]
	if !ok {
		return nil, ErrNotFound
	}
	return cloneUser(user), nil
}

func (r *memoryTxUserRepo) FindByPhone(ctx context.Context, phone string) (*models.User, error) {
	r.tx.mu.RLock()
	defer r.tx.mu.RUnlock()

	targetDigits := extractDigits(phone)
	if len(targetDigits) < 10 {
		return nil, ErrNotFound
	}
	target10 := targetDigits[len(targetDigits)-10:]

	for _, user := range r.tx.users {
		uDigits := extractDigits(user.Phone)
		if len(uDigits) >= 10 && uDigits[len(uDigits)-10:] == target10 {
			return cloneUser(user), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryTxUserRepo) FindByEmail(ctx context.Context, email string) (*models.User, error) {
	r.tx.mu.RLock()
	defer r.tx.mu.RUnlock()

	normalized := strings.ToLower(strings.TrimSpace(email))
	if normalized == "" {
		return nil, ErrNotFound
	}

	for _, user := range r.tx.users {
		if user.Email != nil && strings.ToLower(strings.TrimSpace(*user.Email)) == normalized {
			return cloneUser(user), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryTxUserRepo) Create(ctx context.Context, user *models.User) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	targetDigits := extractDigits(user.Phone)
	if len(targetDigits) >= 10 {
		target10 := targetDigits[len(targetDigits)-10:]
		for _, existing := range r.tx.users {
			eDigits := extractDigits(existing.Phone)
			if len(eDigits) >= 10 && eDigits[len(eDigits)-10:] == target10 {
				return ErrAlreadyExists
			}
		}
	}

	if user.Email != nil && strings.TrimSpace(*user.Email) != "" {
		targetEmail := strings.ToLower(strings.TrimSpace(*user.Email))
		for _, existing := range r.tx.users {
			if existing.Email != nil && strings.ToLower(strings.TrimSpace(*existing.Email)) == targetEmail {
				return ErrAlreadyExists
			}
		}
	}

	if user.ID == uuid.Nil {
		user.ID = uuid.New()
	}
	now := time.Now().UTC()
	user.CreatedAt = now
	user.UpdatedAt = now

	r.tx.users[user.ID] = cloneUser(user)
	return nil
}

func (r *memoryTxUserRepo) Update(ctx context.Context, user *models.User) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	existing, ok := r.tx.users[user.ID]
	if !ok {
		return ErrNotFound
	}

	targetDigits := extractDigits(user.Phone)
	if len(targetDigits) >= 10 {
		target10 := targetDigits[len(targetDigits)-10:]
		for id, other := range r.tx.users {
			if id != user.ID {
				oDigits := extractDigits(other.Phone)
				if len(oDigits) >= 10 && oDigits[len(oDigits)-10:] == target10 {
					return ErrAlreadyExists
				}
			}
		}
	}

	user.UpdatedAt = time.Now().UTC()
	user.CreatedAt = existing.CreatedAt

	r.tx.users[user.ID] = cloneUser(user)
	return nil
}

// -----------------------------------------------------------------------------
// Pending Registrations
// -----------------------------------------------------------------------------
type memoryPendingRepo struct {
	store *MemoryStore
}

func (r *memoryPendingRepo) CreateOrReplace(ctx context.Context, reg *models.PendingRegistration) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	targetDigits := extractDigits(reg.MobileNumber)
	if len(targetDigits) >= 10 {
		target10 := targetDigits[len(targetDigits)-10:]
		for id, p := range r.store.pendingRegistrations {
			pDigits := extractDigits(p.MobileNumber)
			if len(pDigits) >= 10 && pDigits[len(pDigits)-10:] == target10 {
				delete(r.store.pendingRegistrations, id)
			}
		}
	}

	if reg.ID == uuid.Nil {
		reg.ID = uuid.New()
	}
	r.store.pendingRegistrations[reg.ID] = clonePending(reg)
	return nil
}

func (r *memoryPendingRepo) FindByTokenHash(ctx context.Context, tokenHash string) (*models.PendingRegistration, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()

	for _, p := range r.store.pendingRegistrations {
		if p.RegistrationTokenHash == tokenHash {
			return clonePending(p), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryPendingRepo) FindByMobile(ctx context.Context, mobile string) (*models.PendingRegistration, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()

	targetDigits := extractDigits(mobile)
	if len(targetDigits) < 10 {
		return nil, ErrNotFound
	}
	target10 := targetDigits[len(targetDigits)-10:]

	var latest *models.PendingRegistration
	for _, p := range r.store.pendingRegistrations {
		pDigits := extractDigits(p.MobileNumber)
		if len(pDigits) >= 10 && pDigits[len(pDigits)-10:] == target10 {
			if latest == nil || p.CreatedAt.After(latest.CreatedAt) {
				latest = p
			}
		}
	}
	if latest == nil {
		return nil, ErrNotFound
	}
	return clonePending(latest), nil
}

func (r *memoryPendingRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	if _, ok := r.store.pendingRegistrations[id]; !ok {
		return ErrNotFound
	}
	delete(r.store.pendingRegistrations, id)
	return nil
}

// Transactional Pending Repo
type memoryTxPendingRepo struct {
	tx *memoryTxStore
}

func (r *memoryTxPendingRepo) CreateOrReplace(ctx context.Context, reg *models.PendingRegistration) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	targetDigits := extractDigits(reg.MobileNumber)
	if len(targetDigits) >= 10 {
		target10 := targetDigits[len(targetDigits)-10:]
		for id, p := range r.tx.pendingRegistrations {
			pDigits := extractDigits(p.MobileNumber)
			if len(pDigits) >= 10 && pDigits[len(pDigits)-10:] == target10 {
				delete(r.tx.pendingRegistrations, id)
			}
		}
	}

	if reg.ID == uuid.Nil {
		reg.ID = uuid.New()
	}
	r.tx.pendingRegistrations[reg.ID] = clonePending(reg)
	return nil
}

func (r *memoryTxPendingRepo) FindByTokenHash(ctx context.Context, tokenHash string) (*models.PendingRegistration, error) {
	r.tx.mu.RLock()
	defer r.tx.mu.RUnlock()

	for _, p := range r.tx.pendingRegistrations {
		if p.RegistrationTokenHash == tokenHash {
			return clonePending(p), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryTxPendingRepo) FindByMobile(ctx context.Context, mobile string) (*models.PendingRegistration, error) {
	r.tx.mu.RLock()
	defer r.tx.mu.RUnlock()

	targetDigits := extractDigits(mobile)
	if len(targetDigits) < 10 {
		return nil, ErrNotFound
	}
	target10 := targetDigits[len(targetDigits)-10:]

	var latest *models.PendingRegistration
	for _, p := range r.tx.pendingRegistrations {
		pDigits := extractDigits(p.MobileNumber)
		if len(pDigits) >= 10 && pDigits[len(pDigits)-10:] == target10 {
			if latest == nil || p.CreatedAt.After(latest.CreatedAt) {
				latest = p
			}
		}
	}
	if latest == nil {
		return nil, ErrNotFound
	}
	return clonePending(latest), nil
}

func (r *memoryTxPendingRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	if _, ok := r.tx.pendingRegistrations[id]; !ok {
		return ErrNotFound
	}
	delete(r.tx.pendingRegistrations, id)
	return nil
}

// -----------------------------------------------------------------------------
// OTP Challenges
// -----------------------------------------------------------------------------
type memoryOTPRepo struct {
	store *MemoryStore
}

func (r *memoryOTPRepo) Create(ctx context.Context, c *models.OTPChallenge) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	normDest := normalizeDestination(c.Destination)
	for id, existing := range r.store.otpChallenges {
		if existing.Purpose == c.Purpose && normalizeDestination(existing.Destination) == normDest && !existing.IsConsumed {
			delete(r.store.otpChallenges, id)
		}
	}

	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	if c.MaxAttempts <= 0 {
		c.MaxAttempts = 5
	}
	now := time.Now().UTC()
	c.CreatedAt = now

	r.store.otpChallenges[c.ID] = cloneChallenge(c)
	return nil
}

func (r *memoryOTPRepo) FindLatestActive(ctx context.Context, purpose models.OTPPurpose, destination string) (*models.OTPChallenge, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()

	normDest := normalizeDestination(destination)
	var latest *models.OTPChallenge

	for _, c := range r.store.otpChallenges {
		if c.Purpose == purpose && normalizeDestination(c.Destination) == normDest && !c.IsConsumed {
			if latest == nil || c.CreatedAt.After(latest.CreatedAt) {
				latest = c
			}
		}
	}

	if latest == nil {
		return nil, ErrNotFound
	}
	return cloneChallenge(latest), nil
}

func (r *memoryOTPRepo) IncrementFailedAttempts(ctx context.Context, id uuid.UUID) (int, error) {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	c, ok := r.store.otpChallenges[id]
	if !ok {
		return 0, ErrNotFound
	}
	c.FailedAttempts++
	return c.FailedAttempts, nil
}

func (r *memoryOTPRepo) MarkConsumed(ctx context.Context, id uuid.UUID, verifiedAt time.Time) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	c, ok := r.store.otpChallenges[id]
	if !ok {
		return ErrNotFound
	}
	if c.IsConsumed || time.Now().UTC().After(c.ExpiresAt) || c.FailedAttempts >= c.MaxAttempts {
		return ErrChallengeAlreadyConsumed
	}
	c.IsConsumed = true
	v := verifiedAt.UTC()
	c.VerifiedAt = &v
	return nil
}

func (r *memoryOTPRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	delete(r.store.otpChallenges, id)
	return nil
}

// Transactional OTP Repo
type memoryTxOTPRepo struct {
	tx *memoryTxStore
}

func (r *memoryTxOTPRepo) Create(ctx context.Context, c *models.OTPChallenge) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	normDest := normalizeDestination(c.Destination)
	for id, existing := range r.tx.otpChallenges {
		if existing.Purpose == c.Purpose && normalizeDestination(existing.Destination) == normDest && !existing.IsConsumed {
			delete(r.tx.otpChallenges, id)
		}
	}

	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	if c.MaxAttempts <= 0 {
		c.MaxAttempts = 5
	}
	now := time.Now().UTC()
	c.CreatedAt = now

	r.tx.otpChallenges[c.ID] = cloneChallenge(c)
	return nil
}

func (r *memoryTxOTPRepo) FindLatestActive(ctx context.Context, purpose models.OTPPurpose, destination string) (*models.OTPChallenge, error) {
	r.tx.mu.RLock()
	defer r.tx.mu.RUnlock()

	normDest := normalizeDestination(destination)
	var latest *models.OTPChallenge

	for _, c := range r.tx.otpChallenges {
		if c.Purpose == purpose && normalizeDestination(c.Destination) == normDest && !c.IsConsumed {
			if latest == nil || c.CreatedAt.After(latest.CreatedAt) {
				latest = c
			}
		}
	}

	if latest == nil {
		return nil, ErrNotFound
	}
	return cloneChallenge(latest), nil
}

func (r *memoryTxOTPRepo) IncrementFailedAttempts(ctx context.Context, id uuid.UUID) (int, error) {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	c, ok := r.tx.otpChallenges[id]
	if !ok {
		return 0, ErrNotFound
	}
	c.FailedAttempts++
	return c.FailedAttempts, nil
}

func (r *memoryTxOTPRepo) MarkConsumed(ctx context.Context, id uuid.UUID, verifiedAt time.Time) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	c, ok := r.tx.otpChallenges[id]
	if !ok {
		return ErrNotFound
	}
	if c.IsConsumed || time.Now().UTC().After(c.ExpiresAt) || c.FailedAttempts >= c.MaxAttempts {
		return ErrChallengeAlreadyConsumed
	}
	c.IsConsumed = true
	v := verifiedAt.UTC()
	c.VerifiedAt = &v
	return nil
}

func (r *memoryTxOTPRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	delete(r.tx.otpChallenges, id)
	return nil
}

// -----------------------------------------------------------------------------
// Dev Test Numbers
// -----------------------------------------------------------------------------
type memoryDevNumberRepo struct {
	store *MemoryStore
}

func (r *memoryDevNumberRepo) FindByPhone(ctx context.Context, phone string) (*models.DevTestNumber, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()

	targetDigits := extractDigits(phone)
	if len(targetDigits) < 10 {
		return nil, ErrNotFound
	}
	target10 := targetDigits[len(targetDigits)-10:]

	for _, n := range r.store.devTestNumbers {
		nDigits := extractDigits(n.MobileNumber)
		if len(nDigits) >= 10 && nDigits[len(nDigits)-10:] == target10 {
			return cloneDevNumber(n), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryDevNumberRepo) Set(ctx context.Context, entry *models.DevTestNumber) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	if entry.ID == uuid.Nil {
		entry.ID = uuid.New()
	}
	targetDigits := extractDigits(entry.MobileNumber)
	if len(targetDigits) >= 10 {
		target10 := targetDigits[len(targetDigits)-10:]
		for key, n := range r.store.devTestNumbers {
			nDigits := extractDigits(n.MobileNumber)
			if len(nDigits) >= 10 && nDigits[len(nDigits)-10:] == target10 {
				delete(r.store.devTestNumbers, key)
			}
		}
	}

	r.store.devTestNumbers[entry.MobileNumber] = cloneDevNumber(entry)
	return nil
}

// Transactional Dev Number Repo
type memoryTxDevNumberRepo struct {
	tx *memoryTxStore
}

func (r *memoryTxDevNumberRepo) FindByPhone(ctx context.Context, phone string) (*models.DevTestNumber, error) {
	r.tx.mu.RLock()
	defer r.tx.mu.RUnlock()

	targetDigits := extractDigits(phone)
	if len(targetDigits) < 10 {
		return nil, ErrNotFound
	}
	target10 := targetDigits[len(targetDigits)-10:]

	for _, n := range r.tx.devTestNumbers {
		nDigits := extractDigits(n.MobileNumber)
		if len(nDigits) >= 10 && nDigits[len(nDigits)-10:] == target10 {
			return cloneDevNumber(n), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryTxDevNumberRepo) Set(ctx context.Context, entry *models.DevTestNumber) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	if entry.ID == uuid.Nil {
		entry.ID = uuid.New()
	}
	targetDigits := extractDigits(entry.MobileNumber)
	if len(targetDigits) >= 10 {
		target10 := targetDigits[len(targetDigits)-10:]
		for key, n := range r.tx.devTestNumbers {
			nDigits := extractDigits(n.MobileNumber)
			if len(nDigits) >= 10 && nDigits[len(nDigits)-10:] == target10 {
				delete(r.tx.devTestNumbers, key)
			}
		}
	}

	r.tx.devTestNumbers[entry.MobileNumber] = cloneDevNumber(entry)
	return nil
}

// -----------------------------------------------------------------------------
// Sessions
// -----------------------------------------------------------------------------
type memorySessionRepo struct {
	store *MemoryStore
}

func (r *memorySessionRepo) Create(ctx context.Context, s *models.Session) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	r.store.sessions[s.ID] = cloneSession(s)
	return nil
}

func (r *memorySessionRepo) FindByTokenHash(ctx context.Context, tokenHash string) (*models.Session, error) {
	r.store.mu.RLock()
	defer r.store.mu.RUnlock()

	for _, s := range r.store.sessions {
		if s.TokenHash == tokenHash {
			return cloneSession(s), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memorySessionRepo) Revoke(ctx context.Context, id uuid.UUID) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	s, ok := r.store.sessions[id]
	if !ok {
		return ErrNotFound
	}
	if s.RevokedAt != nil || time.Now().UTC().After(s.ExpiresAt) {
		return ErrSessionAlreadyRevoked
	}
	now := time.Now().UTC()
	s.RevokedAt = &now
	return nil
}

func (r *memorySessionRepo) RevokeAllForUser(ctx context.Context, userID uuid.UUID) error {
	r.store.mu.Lock()
	defer r.store.mu.Unlock()

	now := time.Now().UTC()
	for _, s := range r.store.sessions {
		if s.UserID == userID && s.RevokedAt == nil {
			s.RevokedAt = &now
		}
	}
	return nil
}

// Transactional Session Repo
type memoryTxSessionRepo struct {
	tx *memoryTxStore
}

func (r *memoryTxSessionRepo) Create(ctx context.Context, s *models.Session) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	r.tx.sessions[s.ID] = cloneSession(s)
	return nil
}

func (r *memoryTxSessionRepo) FindByTokenHash(ctx context.Context, tokenHash string) (*models.Session, error) {
	r.tx.mu.RLock()
	defer r.tx.mu.RUnlock()

	for _, s := range r.tx.sessions {
		if s.TokenHash == tokenHash {
			return cloneSession(s), nil
		}
	}
	return nil, ErrNotFound
}

func (r *memoryTxSessionRepo) Revoke(ctx context.Context, id uuid.UUID) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	s, ok := r.tx.sessions[id]
	if !ok {
		return ErrNotFound
	}
	if s.RevokedAt != nil || time.Now().UTC().After(s.ExpiresAt) {
		return ErrSessionAlreadyRevoked
	}
	now := time.Now().UTC()
	s.RevokedAt = &now
	return nil
}

func (r *memoryTxSessionRepo) RevokeAllForUser(ctx context.Context, userID uuid.UUID) error {
	r.tx.mu.Lock()
	defer r.tx.mu.Unlock()

	now := time.Now().UTC()
	for _, s := range r.tx.sessions {
		if s.UserID == userID && s.RevokedAt == nil {
			s.RevokedAt = &now
		}
	}
	return nil
}

// -----------------------------------------------------------------------------
// Deep Copy Helpers
// -----------------------------------------------------------------------------
func cloneUser(u *models.User) *models.User {
	if u == nil {
		return nil
	}
	cp := *u
	if u.PhoneConfirmedAt != nil {
		t := *u.PhoneConfirmedAt
		cp.PhoneConfirmedAt = &t
	}
	if u.Email != nil {
		e := *u.Email
		cp.Email = &e
	}
	if u.EmailConfirmedAt != nil {
		t := *u.EmailConfirmedAt
		cp.EmailConfirmedAt = &t
	}
	return &cp
}

func clonePending(p *models.PendingRegistration) *models.PendingRegistration {
	if p == nil {
		return nil
	}
	cp := *p
	if p.VerifiedAt != nil {
		t := *p.VerifiedAt
		cp.VerifiedAt = &t
	}
	return &cp
}

func cloneChallenge(c *models.OTPChallenge) *models.OTPChallenge {
	if c == nil {
		return nil
	}
	cp := *c
	if c.ReferenceID != nil {
		ref := *c.ReferenceID
		cp.ReferenceID = &ref
	}
	if c.VerifiedAt != nil {
		t := *c.VerifiedAt
		cp.VerifiedAt = &t
	}
	return &cp
}

func cloneSession(s *models.Session) *models.Session {
	if s == nil {
		return nil
	}
	cp := *s
	if s.RevokedAt != nil {
		t := *s.RevokedAt
		cp.RevokedAt = &t
	}
	return &cp
}

func cloneDevNumber(n *models.DevTestNumber) *models.DevTestNumber {
	if n == nil {
		return nil
	}
	cp := *n
	return &cp
}

func cloneUserMap(src map[uuid.UUID]*models.User) map[uuid.UUID]*models.User {
	dst := make(map[uuid.UUID]*models.User, len(src))
	for k, v := range src {
		dst[k] = cloneUser(v)
	}
	return dst
}

func clonePendingMap(src map[uuid.UUID]*models.PendingRegistration) map[uuid.UUID]*models.PendingRegistration {
	dst := make(map[uuid.UUID]*models.PendingRegistration, len(src))
	for k, v := range src {
		dst[k] = clonePending(v)
	}
	return dst
}

func cloneChallengeMap(src map[uuid.UUID]*models.OTPChallenge) map[uuid.UUID]*models.OTPChallenge {
	dst := make(map[uuid.UUID]*models.OTPChallenge, len(src))
	for k, v := range src {
		dst[k] = cloneChallenge(v)
	}
	return dst
}

func cloneSessionMap(src map[uuid.UUID]*models.Session) map[uuid.UUID]*models.Session {
	dst := make(map[uuid.UUID]*models.Session, len(src))
	for k, v := range src {
		dst[k] = cloneSession(v)
	}
	return dst
}

func cloneDevNumberMap(src map[string]*models.DevTestNumber) map[string]*models.DevTestNumber {
	dst := make(map[string]*models.DevTestNumber, len(src))
	for k, v := range src {
		dst[k] = cloneDevNumber(v)
	}
	return dst
}

func extractDigits(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func normalizeDestination(d string) string {
	digits := extractDigits(d)
	if len(digits) >= 10 {
		return digits[len(digits)-10:]
	}
	return strings.ToLower(strings.TrimSpace(d))
}
