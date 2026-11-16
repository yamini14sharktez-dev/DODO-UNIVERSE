package database

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"dodo-universe-backend/internal/models"
	"github.com/google/uuid"
	_ "github.com/lib/pq"
)

// PostgresStore implements Store using PostgreSQL.
type PostgresStore struct {
	db *sql.DB
	tx *sql.Tx
}

// NewPostgresStore establishes a connection pool to PostgreSQL without running automatic migrations.
func NewPostgresStore(databaseURL string) (*PostgresStore, error) {
	if databaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL cannot be empty")
	}

	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}

	// Connection pool settings
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(5 * time.Minute)
	db.SetConnMaxIdleTime(2 * time.Minute)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("failed to ping PostgreSQL: %w", err)
	}

	return &PostgresStore{db: db}, nil
}

func (p *PostgresStore) Users() UserRepository {
	return &pgUserRepo{db: p.db, tx: p.tx}
}

func (p *PostgresStore) PendingRegistrations() PendingRegistrationRepository {
	return &pgPendingRepo{db: p.db, tx: p.tx}
}

func (p *PostgresStore) OTPChallenges() OTPChallengeRepository {
	return &pgOTPRepo{db: p.db, tx: p.tx}
}

func (p *PostgresStore) Sessions() SessionRepository {
	return &pgSessionRepo{db: p.db, tx: p.tx}
}

func (p *PostgresStore) DevTestNumbers() DevTestNumberRepository {
	return &pgDevNumberRepo{db: p.db, tx: p.tx}
}

func (p *PostgresStore) WithTx(ctx context.Context, fn func(tx Store) error) error {
	if p.tx != nil {
		// Already in transaction
		return fn(p)
	}

	tx, err := p.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	defer func() {
		if r := recover(); r != nil {
			_ = tx.Rollback()
			panic(r)
		}
	}()

	txStore := &PostgresStore{db: p.db, tx: tx}
	if err := fn(txStore); err != nil {
		_ = tx.Rollback()
		return err
	}

	return tx.Commit()
}

func (p *PostgresStore) Close() error {
	if p.db != nil {
		return p.db.Close()
	}
	return nil
}

func (p *PostgresStore) Ping(ctx context.Context) error {
	if p.db != nil {
		return p.db.PingContext(ctx)
	}
	return fmt.Errorf("database not initialized")
}

// -----------------------------------------------------------------------------
// Executor helper for DB or TX
// -----------------------------------------------------------------------------
type queryExec interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
}

func getExec(db *sql.DB, tx *sql.Tx) queryExec {
	if tx != nil {
		return tx
	}
	return db
}

// -----------------------------------------------------------------------------
// pgUserRepo
// -----------------------------------------------------------------------------
type pgUserRepo struct {
	db *sql.DB
	tx *sql.Tx
}

func (r *pgUserRepo) FindByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	row := getExec(r.db, r.tx).QueryRowContext(ctx, `
		SELECT id, COALESCE(phone, ''), phone_confirmed_at, email, email_confirmed_at, full_name, role, is_registration_complete, created_at, updated_at
		FROM public.app_users WHERE id = $1
	`, id)
	return scanUser(row)
}

func (r *pgUserRepo) FindByPhone(ctx context.Context, phone string) (*models.User, error) {
	digits := extractDigits(phone)
	if len(digits) >= 10 {
		digits = digits[len(digits)-10:]
	}
	row := getExec(r.db, r.tx).QueryRowContext(ctx, `
		SELECT id, COALESCE(phone, ''), phone_confirmed_at, email, email_confirmed_at, full_name, role, is_registration_complete, created_at, updated_at
		FROM public.app_users WHERE RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = $1
		LIMIT 1
	`, digits)
	return scanUser(row)
}

func (r *pgUserRepo) FindByEmail(ctx context.Context, email string) (*models.User, error) {
	row := getExec(r.db, r.tx).QueryRowContext(ctx, `
		SELECT id, COALESCE(phone, ''), phone_confirmed_at, email, email_confirmed_at, full_name, role, is_registration_complete, created_at, updated_at
		FROM public.app_users WHERE LOWER(email) = LOWER($1)
		LIMIT 1
	`, email)
	return scanUser(row)
}

func (r *pgUserRepo) Create(ctx context.Context, user *models.User) error {
	if user.ID == uuid.Nil {
		user.ID = uuid.New()
	}
	now := time.Now().UTC()
	user.CreatedAt = now
	user.UpdatedAt = now

	_, err := getExec(r.db, r.tx).ExecContext(ctx, `
		INSERT INTO public.app_users (id, phone, phone_confirmed_at, email, email_confirmed_at, full_name, role, is_registration_complete, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, user.ID, user.Phone, user.PhoneConfirmedAt, user.Email, user.EmailConfirmedAt, user.FullName, string(user.Role), user.IsRegistrationComplete, user.CreatedAt, user.UpdatedAt)
	return err
}

func (r *pgUserRepo) Update(ctx context.Context, user *models.User) error {
	user.UpdatedAt = time.Now().UTC()
	_, err := getExec(r.db, r.tx).ExecContext(ctx, `
		UPDATE public.app_users
		SET phone = $2, phone_confirmed_at = $3, email = $4, email_confirmed_at = $5, full_name = $6, role = $7, is_registration_complete = $8, updated_at = $9
		WHERE id = $1
	`, user.ID, user.Phone, user.PhoneConfirmedAt, user.Email, user.EmailConfirmedAt, user.FullName, string(user.Role), user.IsRegistrationComplete, user.UpdatedAt)
	return err
}

func scanUser(row *sql.Row) (*models.User, error) {
	var u models.User
	var role string
	err := row.Scan(
		&u.ID,
		&u.Phone,
		&u.PhoneConfirmedAt,
		&u.Email,
		&u.EmailConfirmedAt,
		&u.FullName,
		&role,
		&u.IsRegistrationComplete,
		&u.CreatedAt,
		&u.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, err
	}
	u.Role = models.UserRole(role)
	return &u, nil
}

// -----------------------------------------------------------------------------
// pgPendingRepo
// -----------------------------------------------------------------------------
type pgPendingRepo struct {
	db *sql.DB
	tx *sql.Tx
}

func (r *pgPendingRepo) CreateOrReplace(ctx context.Context, reg *models.PendingRegistration) error {
	if reg.ID == uuid.Nil {
		reg.ID = uuid.New()
	}
	digits := extractDigits(reg.MobileNumber)
	if len(digits) >= 10 {
		digits = digits[len(digits)-10:]
	}
	_, _ = getExec(r.db, r.tx).ExecContext(ctx, `
		DELETE FROM public.app_pending_registrations
		WHERE RIGHT(regexp_replace(mobile_number, '\D', '', 'g'), 10) = $1
	`, digits)

	_, err := getExec(r.db, r.tx).ExecContext(ctx, `
		INSERT INTO public.app_pending_registrations
		(id, user_id, mobile_number, email, full_name, registration_token_hash, is_mobile_verified, is_email_verified, expires_at, created_at, verified_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`, reg.ID, reg.UserID, reg.MobileNumber, reg.Email, reg.FullName, reg.RegistrationTokenHash, reg.IsMobileVerified, reg.IsEmailVerified, reg.ExpiresAt, reg.CreatedAt, reg.VerifiedAt)
	return err
}

func (r *pgPendingRepo) FindByTokenHash(ctx context.Context, tokenHash string) (*models.PendingRegistration, error) {
	row := getExec(r.db, r.tx).QueryRowContext(ctx, `
		SELECT id, user_id, mobile_number, email, full_name, registration_token_hash, is_mobile_verified, is_email_verified, expires_at, created_at, verified_at
		FROM public.app_pending_registrations
		WHERE registration_token_hash = $1
	`, tokenHash)
	return scanPending(row)
}

func (r *pgPendingRepo) FindByMobile(ctx context.Context, mobile string) (*models.PendingRegistration, error) {
	digits := extractDigits(mobile)
	if len(digits) >= 10 {
		digits = digits[len(digits)-10:]
	}
	row := getExec(r.db, r.tx).QueryRowContext(ctx, `
		SELECT id, user_id, mobile_number, email, full_name, registration_token_hash, is_mobile_verified, is_email_verified, expires_at, created_at, verified_at
		FROM public.app_pending_registrations
		WHERE RIGHT(regexp_replace(mobile_number, '\D', '', 'g'), 10) = $1
		ORDER BY created_at DESC LIMIT 1
	`, digits)
	return scanPending(row)
}

func (r *pgPendingRepo) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := getExec(r.db, r.tx).ExecContext(ctx, `DELETE FROM public.app_pending_registrations WHERE id = $1`, id)
	return err
}

func scanPending(row *sql.Row) (*models.PendingRegistration, error) {
	var p models.PendingRegistration
	err := row.Scan(
		&p.ID,
		&p.UserID,
		&p.MobileNumber,
		&p.Email,
		&p.FullName,
		&p.RegistrationTokenHash,
		&p.IsMobileVerified,
		&p.IsEmailVerified,
		&p.ExpiresAt,
		&p.CreatedAt,
		&p.VerifiedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &p, nil
}

// -----------------------------------------------------------------------------
// pgOTPRepo
// -----------------------------------------------------------------------------
type pgOTPRepo struct {
	db *sql.DB
	tx *sql.Tx
}

func (r *pgOTPRepo) Create(ctx context.Context, c *models.OTPChallenge) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	if c.MaxAttempts <= 0 {
		c.MaxAttempts = 5
	}
	now := time.Now().UTC()
	c.CreatedAt = now

	// Invalidate previous active challenge with the SAME purpose and destination
	normDest := normalizeDestination(c.Destination)
	_, _ = getExec(r.db, r.tx).ExecContext(ctx, `
		DELETE FROM public.app_otp_challenges
		WHERE purpose = $1 AND destination = $2 AND is_consumed = false
	`, string(c.Purpose), normDest)

	_, err := getExec(r.db, r.tx).ExecContext(ctx, `
		INSERT INTO public.app_otp_challenges
		(id, purpose, destination, otp_hash, reference_id, failed_attempts, max_attempts, is_consumed, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, c.ID, string(c.Purpose), normDest, c.OTPHash, c.ReferenceID, c.FailedAttempts, c.MaxAttempts, c.IsConsumed, c.ExpiresAt, c.CreatedAt)
	return err
}

func (r *pgOTPRepo) FindLatestActive(ctx context.Context, purpose models.OTPPurpose, destination string) (*models.OTPChallenge, error) {
	normDest := normalizeDestination(destination)
	row := getExec(r.db, r.tx).QueryRowContext(ctx, `
		SELECT id, purpose, destination, otp_hash, reference_id, failed_attempts, max_attempts, is_consumed, expires_at, created_at, verified_at
		FROM public.app_otp_challenges
		WHERE purpose = $1 AND destination = $2 AND is_consumed = false
		ORDER BY created_at DESC LIMIT 1
	`, string(purpose), normDest)

	var c models.OTPChallenge
	var purp string
	err := row.Scan(
		&c.ID,
		&purp,
		&c.Destination,
		&c.OTPHash,
		&c.ReferenceID,
		&c.FailedAttempts,
		&c.MaxAttempts,
		&c.IsConsumed,
		&c.ExpiresAt,
		&c.CreatedAt,
		&c.VerifiedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, err
	}
	c.Purpose = models.OTPPurpose(purp)
	return &c, nil
}

func (r *pgOTPRepo) IncrementFailedAttempts(ctx context.Context, id uuid.UUID) (int, error) {
	var count int
	err := getExec(r.db, r.tx).QueryRowContext(ctx, `
		UPDATE public.app_otp_challenges
		SET failed_attempts = failed_attempts + 1
		WHERE id = $1
		RETURNING failed_attempts
	`, id).Scan(&count)
	return count, err
}

func (r *pgOTPRepo) MarkConsumed(ctx context.Context, id uuid.UUID, verifiedAt time.Time) error {
	now := verifiedAt.UTC()
	res, err := getExec(r.db, r.tx).ExecContext(ctx, `
		UPDATE public.app_otp_challenges
		SET is_consumed = true, verified_at = $2
		WHERE id = $1 
		  AND is_consumed = false 
		  AND failed_attempts < max_attempts 
		  AND expires_at > $2
	`, id, now)
	if err != nil {
		return err
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrChallengeAlreadyConsumed
	}
	return nil
}

func (r *pgOTPRepo) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := getExec(r.db, r.tx).ExecContext(ctx, `DELETE FROM public.app_otp_challenges WHERE id = $1`, id)
	return err
}

// -----------------------------------------------------------------------------
// pgDevNumberRepo
// -----------------------------------------------------------------------------
type pgDevNumberRepo struct {
	db *sql.DB
	tx *sql.Tx
}

func (r *pgDevNumberRepo) FindByPhone(ctx context.Context, phone string) (*models.DevTestNumber, error) {
	digits := extractDigits(phone)
	if len(digits) >= 10 {
		digits = digits[len(digits)-10:]
	}
	row := getExec(r.db, r.tx).QueryRowContext(ctx, `
		SELECT id, mobile_number, test_otp_hash, is_enabled
		FROM public.dev_auth_test_numbers
		WHERE RIGHT(regexp_replace(mobile_number, '\D', '', 'g'), 10) = $1
		LIMIT 1
	`, digits)

	var n models.DevTestNumber
	err := row.Scan(&n.ID, &n.MobileNumber, &n.TestOTPHash, &n.IsEnabled)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &n, nil
}

func (r *pgDevNumberRepo) Set(ctx context.Context, entry *models.DevTestNumber) error {
	if entry.ID == uuid.Nil {
		entry.ID = uuid.New()
	}
	_, err := getExec(r.db, r.tx).ExecContext(ctx, `
		INSERT INTO public.dev_auth_test_numbers (id, mobile_number, test_otp_hash, is_enabled)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (mobile_number) DO UPDATE
		SET test_otp_hash = EXCLUDED.test_otp_hash, is_enabled = EXCLUDED.is_enabled
	`, entry.ID, entry.MobileNumber, entry.TestOTPHash, entry.IsEnabled)
	return err
}

// -----------------------------------------------------------------------------
// pgSessionRepo
// -----------------------------------------------------------------------------
type pgSessionRepo struct {
	db *sql.DB
	tx *sql.Tx
}

func (r *pgSessionRepo) Create(ctx context.Context, s *models.Session) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	_, err := getExec(r.db, r.tx).ExecContext(ctx, `
		INSERT INTO public.app_sessions (id, user_id, token_hash, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`, s.ID, s.UserID, s.TokenHash, s.ExpiresAt, s.CreatedAt)
	return err
}

func (r *pgSessionRepo) FindByTokenHash(ctx context.Context, tokenHash string) (*models.Session, error) {
	var s models.Session
	err := getExec(r.db, r.tx).QueryRowContext(ctx, `
		SELECT id, user_id, token_hash, expires_at, created_at, revoked_at
		FROM public.app_sessions
		WHERE token_hash = $1
	`, tokenHash).Scan(&s.ID, &s.UserID, &s.TokenHash, &s.ExpiresAt, &s.CreatedAt, &s.RevokedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &s, nil
}

func (r *pgSessionRepo) Revoke(ctx context.Context, id uuid.UUID) error {
	now := time.Now().UTC()
	res, err := getExec(r.db, r.tx).ExecContext(ctx, `
		UPDATE public.app_sessions 
		SET revoked_at = $2 
		WHERE id = $1 
		  AND revoked_at IS NULL 
		  AND expires_at > $2
	`, id, now)
	if err != nil {
		return err
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrSessionAlreadyRevoked
	}
	return nil
}

func (r *pgSessionRepo) RevokeAllForUser(ctx context.Context, userID uuid.UUID) error {
	_, err := getExec(r.db, r.tx).ExecContext(ctx, `
		UPDATE public.app_sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL
	`, userID)
	return err
}
