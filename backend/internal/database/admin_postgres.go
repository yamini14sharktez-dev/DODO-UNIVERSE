package database

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"dodo-universe-backend/internal/models"
	"github.com/google/uuid"
)

type pgAdminRepo struct {
	db *sql.DB
	tx *sql.Tx
}

func (p *PostgresStore) Admin() AdminRepository {
	return &pgAdminRepo{db: p.db, tx: p.tx}
}

func (r *pgAdminRepo) q() queryExec {
	return getExec(r.db, r.tx)
}

// -----------------------------------------------------------------------------
// 1. Admin Authentication & RBAC
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) FindAdminByID(ctx context.Context, id uuid.UUID) (*models.AdminUser, error) {
	query := `
		SELECT id, email, phone, password_hash, full_name, role, is_active, 
		       failed_login_attempts, locked_until, last_login_at, created_at, updated_at
		FROM public.admin_users
		WHERE id = $1
	`
	u := &models.AdminUser{}
	var roleStr string
	err := r.q().QueryRowContext(ctx, query, id).Scan(
		&u.ID, &u.Email, &u.Phone, &u.PasswordHash, &u.FullName, &roleStr,
		&u.IsActive, &u.FailedLoginAttempts, &u.LockedUntil, &u.LastLoginAt,
		&u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to find admin by id: %w", err)
	}
	u.Role = models.AdminRole(roleStr)
	return u, nil
}

func (r *pgAdminRepo) FindAdminByEmailOrPhone(ctx context.Context, identifier string) (*models.AdminUser, error) {
	norm := strings.TrimSpace(strings.ToLower(identifier))
	query := `
		SELECT id, email, phone, password_hash, full_name, role, is_active, 
		       failed_login_attempts, locked_until, last_login_at, created_at, updated_at
		FROM public.admin_users
		WHERE LOWER(email) = $1 OR phone = $1
	`
	u := &models.AdminUser{}
	var roleStr string
	err := r.q().QueryRowContext(ctx, query, norm).Scan(
		&u.ID, &u.Email, &u.Phone, &u.PasswordHash, &u.FullName, &roleStr,
		&u.IsActive, &u.FailedLoginAttempts, &u.LockedUntil, &u.LastLoginAt,
		&u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("failed to find admin by identifier: %w", err)
	}
	u.Role = models.AdminRole(roleStr)
	return u, nil
}

func (r *pgAdminRepo) CreateAdmin(ctx context.Context, a *models.AdminUser) error {
	query := `
		INSERT INTO public.admin_users (
			id, email, phone, password_hash, full_name, role, is_active, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	now := time.Now().UTC()
	a.CreatedAt = now
	a.UpdatedAt = now

	_, err := r.q().ExecContext(ctx, query,
		a.ID, a.Email, a.Phone, a.PasswordHash, a.FullName, string(a.Role),
		a.IsActive, a.CreatedAt, a.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to create admin user: %w", err)
	}
	return nil
}

func (r *pgAdminRepo) UpdateAdmin(ctx context.Context, a *models.AdminUser) error {
	query := `
		UPDATE public.admin_users
		SET email = $2, phone = $3, full_name = $4, role = $5, is_active = $6, updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.q().ExecContext(ctx, query,
		a.ID, a.Email, a.Phone, a.FullName, string(a.Role), a.IsActive,
	)
	if err != nil {
		return fmt.Errorf("failed to update admin user: %w", err)
	}
	return nil
}

func (r *pgAdminRepo) ListAdmins(ctx context.Context) ([]*models.AdminUser, error) {
	query := `
		SELECT id, email, phone, full_name, role, is_active, last_login_at, created_at, updated_at
		FROM public.admin_users
		ORDER BY created_at ASC
	`
	rows, err := r.q().QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query admin users: %w", err)
	}
	defer rows.Close()

	var list []*models.AdminUser
	for rows.Next() {
		u := &models.AdminUser{}
		var roleStr string
		if err := rows.Scan(
			&u.ID, &u.Email, &u.Phone, &u.FullName, &roleStr, &u.IsActive,
			&u.LastLoginAt, &u.CreatedAt, &u.UpdatedAt,
		); err != nil {
			return nil, err
		}
		u.Role = models.AdminRole(roleStr)
		list = append(list, u)
	}
	return list, nil
}

func (r *pgAdminRepo) RecordAdminFailedLogin(ctx context.Context, id uuid.UUID, lockUntil *time.Time) error {
	query := `
		UPDATE public.admin_users
		SET failed_login_attempts = failed_login_attempts + 1,
		    locked_until = $2,
		    updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.q().ExecContext(ctx, query, id, lockUntil)
	return err
}

func (r *pgAdminRepo) ResetAdminFailedLogins(ctx context.Context, id uuid.UUID) error {
	now := time.Now().UTC()
	query := `
		UPDATE public.admin_users
		SET failed_login_attempts = 0,
		    locked_until = NULL,
		    last_login_at = $2,
		    updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.q().ExecContext(ctx, query, id, now)
	return err
}

func (r *pgAdminRepo) CreateAdminSession(ctx context.Context, s *models.AdminSession) error {
	query := `
		INSERT INTO public.admin_sessions (id, admin_id, token_hash, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := r.q().ExecContext(ctx, query, s.ID, s.AdminID, s.TokenHash, s.ExpiresAt, s.CreatedAt)
	return err
}

func (r *pgAdminRepo) FindAdminSessionByTokenHash(ctx context.Context, tokenHash string) (*models.AdminSession, error) {
	query := `
		SELECT id, admin_id, token_hash, expires_at, created_at, revoked_at
		FROM public.admin_sessions
		WHERE token_hash = $1
	`
	s := &models.AdminSession{}
	err := r.q().QueryRowContext(ctx, query, tokenHash).Scan(
		&s.ID, &s.AdminID, &s.TokenHash, &s.ExpiresAt, &s.CreatedAt, &s.RevokedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if s.RevokedAt != nil || time.Now().UTC().After(s.ExpiresAt) {
		return nil, ErrSessionAlreadyRevoked
	}
	return s, nil
}

func (r *pgAdminRepo) RevokeAdminSession(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE public.admin_sessions SET revoked_at = NOW() WHERE id = $1`
	_, err := r.q().ExecContext(ctx, query, id)
	return err
}

// -----------------------------------------------------------------------------
// 2. Dashboard KPIs & Aggregations (Live Postgres counts only)
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) GetDashboardMetrics(ctx context.Context) (*models.AdminDashboardMetrics, error) {
	m := &models.AdminDashboardMetrics{}

	// Query live table counts directly without any fabrication
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.app_users`).Scan(&m.TotalPeople)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.vendor_applications WHERE status = 'approved'`).Scan(&m.ActiveVendors)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.vendor_applications WHERE status = 'pending'`).Scan(&m.PendingVendorApplications)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.service_categories WHERE category_type = 'bookable_service' OR allow_listings = TRUE`).Scan(&m.TotalServices)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.service_categories`).Scan(&m.TotalCategories)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.product_listings WHERE is_active = TRUE`).Scan(&m.TotalListings)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.orders`).Scan(&m.TotalOrders)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.orders WHERE status = 'pending'`).Scan(&m.PendingOrders)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.orders WHERE status = 'completed'`).Scan(&m.CompletedOrders)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.orders WHERE status = 'cancelled'`).Scan(&m.CancelledOrders)
	_ = r.q().QueryRowContext(ctx, `SELECT COUNT(*) FROM public.quotation_requests WHERE status = 'open'`).Scan(&m.PendingQuoteRequests)

	var vol sql.NullFloat64
	_ = r.q().QueryRowContext(ctx, `SELECT SUM(amount) FROM public.payment_records WHERE status = 'successful'`).Scan(&vol)
	if vol.Valid {
		m.TotalPaymentVolume = vol.Float64
	}

	// Fetch recent audit logs
	recent, _, err := r.ListAuditLogs(ctx, "", "", 10, 0)
	if err == nil {
		m.RecentActivity = recent
	} else {
		m.RecentActivity = []*models.AuditLog{}
	}

	return m, nil
}

// -----------------------------------------------------------------------------
// 3. People Management (Unified app_users accounts)
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) ListPeople(ctx context.Context, search string, limit, offset int) ([]*models.User, int64, error) {
	if limit <= 0 {
		limit = 20
	}
	searchClause := ""
	var args []interface{}
	argIdx := 1

	if search != "" {
		searchClause = fmt.Sprintf("WHERE (LOWER(full_name) LIKE $%d OR phone LIKE $%d OR LOWER(email) LIKE $%d)", argIdx, argIdx, argIdx)
		args = append(args, "%"+strings.ToLower(search)+"%")
		argIdx++
	}

	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM public.app_users %s", searchClause)
	var total int64
	if err := r.q().QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := fmt.Sprintf(`
		SELECT id, phone, phone_confirmed_at, email, email_confirmed_at, full_name, role, is_registration_complete, created_at, updated_at
		FROM public.app_users
		%s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, searchClause, argIdx, argIdx+1)

	args = append(args, limit, offset)
	rows, err := r.q().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var users []*models.User
	for rows.Next() {
		u := &models.User{}
		var roleStr string
		if err := rows.Scan(
			&u.ID, &u.Phone, &u.PhoneConfirmedAt, &u.Email, &u.EmailConfirmedAt,
			&u.FullName, &roleStr, &u.IsRegistrationComplete, &u.CreatedAt, &u.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		u.Role = models.UserRole(roleStr)
		users = append(users, u)
	}

	return users, total, nil
}

func (r *pgAdminRepo) GetPersonDetails(ctx context.Context, id uuid.UUID) (*models.User, []*models.AdminOrder, []*models.VendorApplication, []*models.ProductListing, error) {
	// 1. Fetch user
	userQuery := `
		SELECT id, phone, phone_confirmed_at, email, email_confirmed_at, full_name, role, is_registration_complete, created_at, updated_at
		FROM public.app_users
		WHERE id = $1
	`
	u := &models.User{}
	var roleStr string
	err := r.q().QueryRowContext(ctx, userQuery, id).Scan(
		&u.ID, &u.Phone, &u.PhoneConfirmedAt, &u.Email, &u.EmailConfirmedAt,
		&u.FullName, &roleStr, &u.IsRegistrationComplete, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil, nil, nil, ErrNotFound
		}
		return nil, nil, nil, nil, err
	}
	u.Role = models.UserRole(roleStr)

	// 2. Fetch customer & vendor orders
	ordersQuery := `
		SELECT o.id, o.customer_id, cu.full_name, cu.phone, o.vendor_id, vu.full_name, vu.phone,
		       o.listing_id, COALESCE(pl.title, ''), o.status, o.total_amount, o.commission_amount, 
		       o.order_details, o.created_at, o.updated_at
		FROM public.orders o
		LEFT JOIN public.app_users cu ON cu.id = o.customer_id
		LEFT JOIN public.app_users vu ON vu.id = o.vendor_id
		LEFT JOIN public.product_listings pl ON pl.id = o.listing_id
		WHERE o.customer_id = $1 OR o.vendor_id = $1
		ORDER BY o.created_at DESC
		LIMIT 50
	`
	oRows, err := r.q().QueryContext(ctx, ordersQuery, id)
	var orders []*models.AdminOrder
	if err == nil {
		defer oRows.Close()
		for oRows.Next() {
			ao := &models.AdminOrder{}
			var details []byte
			_ = oRows.Scan(
				&ao.ID, &ao.CustomerID, &ao.CustomerName, &ao.CustomerPhone,
				&ao.VendorID, &ao.VendorName, &ao.VendorPhone,
				&ao.ListingID, &ao.ListingTitle, &ao.Status, &ao.TotalAmount, &ao.CommissionAmount,
				&details, &ao.CreatedAt, &ao.UpdatedAt,
			)
			ao.OrderDetails = details
			orders = append(orders, ao)
		}
	}

	// 3. Fetch vendor applications
	appQuery := `
		SELECT va.id, va.user_id, va.business_name, va.business_type, va.status, 
		       va.submitted_data, va.documents, va.created_at, va.updated_at
		FROM public.vendor_applications va
		WHERE va.user_id = $1
		ORDER BY va.created_at DESC
	`
	aRows, err := r.q().QueryContext(ctx, appQuery, id)
	var apps []*models.VendorApplication
	if err == nil {
		defer aRows.Close()
		for aRows.Next() {
			va := &models.VendorApplication{}
			var subData, docs []byte
			_ = aRows.Scan(
				&va.ID, &va.UserID, &va.BusinessName, &va.BusinessType, &va.Status,
				&subData, &docs, &va.CreatedAt, &va.UpdatedAt,
			)
			va.SubmittedData = subData
			va.Documents = docs
			apps = append(apps, va)
		}
	}

	// 4. Fetch vendor product listings
	listQuery := `
		SELECT pl.id, pl.vendor_id, pl.category_id, COALESCE(sc.name, ''), pl.title, pl.description,
		       pl.listing_type, pl.unit_price, pl.pricing_unit, pl.min_order_quantity,
		       pl.has_transportation, pl.transportation_fee, pl.is_active, pl.approval_status,
		       pl.created_at, pl.updated_at
		FROM public.product_listings pl
		LEFT JOIN public.service_categories sc ON sc.id = pl.category_id
		WHERE pl.vendor_id = $1
		ORDER BY pl.created_at DESC
	`
	lRows, err := r.q().QueryContext(ctx, listQuery, id)
	var listings []*models.ProductListing
	if err == nil {
		defer lRows.Close()
		for lRows.Next() {
			pl := &models.ProductListing{}
			_ = lRows.Scan(
				&pl.ID, &pl.VendorID, &pl.CategoryID, &pl.CategoryName, &pl.Title, &pl.Description,
				&pl.ListingType, &pl.UnitPrice, &pl.PricingUnit, &pl.MinOrderQuantity,
				&pl.HasTransportation, &pl.TransportationFee, &pl.IsActive, &pl.ApprovalStatus,
				&pl.CreatedAt, &pl.UpdatedAt,
			)
			listings = append(listings, pl)
		}
	}

	return u, orders, apps, listings, nil
}

func (r *pgAdminRepo) SetPersonStatus(ctx context.Context, id uuid.UUID, isSuspended bool) error {
	newRole := models.RoleUser
	if isSuspended {
		newRole = "suspended"
	}
	_, err := r.q().ExecContext(ctx, "UPDATE public.app_users SET role = $2, updated_at = NOW() WHERE id = $1", id, newRole)
	return err
}

// -----------------------------------------------------------------------------
// 4. Vendor Applications
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) ListVendorApplications(ctx context.Context, status string, limit, offset int) ([]*models.VendorApplication, int64, error) {
	if limit <= 0 {
		limit = 20
	}
	statusClause := ""
	var args []interface{}
	argIdx := 1

	if status != "" {
		statusClause = fmt.Sprintf("WHERE va.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}

	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM public.vendor_applications va %s", statusClause)
	var total int64
	if err := r.q().QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := fmt.Sprintf(`
		SELECT va.id, va.user_id, COALESCE(u.full_name, ''), COALESCE(u.phone, ''), COALESCE(u.email, ''),
		       va.category_id, COALESCE(sc.name, ''), va.business_name, va.business_type, va.status,
		       va.submitted_data, va.documents, va.rejection_reason, va.info_request_notes,
		       va.reviewed_by, va.reviewed_at, va.created_at, va.updated_at
		FROM public.vendor_applications va
		JOIN public.app_users u ON u.id = va.user_id
		LEFT JOIN public.service_categories sc ON sc.id = va.category_id
		%s
		ORDER BY va.created_at DESC
		LIMIT $%d OFFSET $%d
	`, statusClause, argIdx, argIdx+1)

	args = append(args, limit, offset)
	rows, err := r.q().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*models.VendorApplication
	for rows.Next() {
		va := &models.VendorApplication{}
		var subData, docs []byte
		var catID, revBy *uuid.UUID
		if err := rows.Scan(
			&va.ID, &va.UserID, &va.UserFullName, &va.UserPhone, &va.UserEmail,
			&catID, &va.CategoryName, &va.BusinessName, &va.BusinessType, &va.Status,
			&subData, &docs, &va.RejectionReason, &va.InfoRequestNotes,
			&revBy, &va.ReviewedAt, &va.CreatedAt, &va.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		va.CategoryID = catID
		va.ReviewedBy = revBy
		va.SubmittedData = subData
		va.Documents = docs
		list = append(list, va)
	}

	return list, total, nil
}

func (r *pgAdminRepo) GetVendorApplication(ctx context.Context, id uuid.UUID) (*models.VendorApplication, error) {
	query := `
		SELECT va.id, va.user_id, COALESCE(u.full_name, ''), COALESCE(u.phone, ''), COALESCE(u.email, ''),
		       va.category_id, COALESCE(sc.name, ''), va.business_name, va.business_type, va.status,
		       va.submitted_data, va.documents, va.rejection_reason, va.info_request_notes,
		       va.reviewed_by, va.reviewed_at, va.created_at, va.updated_at
		FROM public.vendor_applications va
		JOIN public.app_users u ON u.id = va.user_id
		LEFT JOIN public.service_categories sc ON sc.id = va.category_id
		WHERE va.id = $1
	`
	va := &models.VendorApplication{}
	var subData, docs []byte
	var catID, revBy *uuid.UUID
	err := r.q().QueryRowContext(ctx, query, id).Scan(
		&va.ID, &va.UserID, &va.UserFullName, &va.UserPhone, &va.UserEmail,
		&catID, &va.CategoryName, &va.BusinessName, &va.BusinessType, &va.Status,
		&subData, &docs, &va.RejectionReason, &va.InfoRequestNotes,
		&revBy, &va.ReviewedAt, &va.CreatedAt, &va.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	va.CategoryID = catID
	va.ReviewedBy = revBy
	va.SubmittedData = subData
	va.Documents = docs
	return va, nil
}

func (r *pgAdminRepo) UpdateVendorApplication(ctx context.Context, app *models.VendorApplication) error {
	now := time.Now().UTC()
	query := `
		UPDATE public.vendor_applications
		SET status = $2, rejection_reason = $3, info_request_notes = $4,
		    reviewed_by = $5, reviewed_at = $6, updated_at = $7
		WHERE id = $1
	`
	_, err := r.q().ExecContext(ctx, query,
		app.ID, app.Status, app.RejectionReason, app.InfoRequestNotes,
		app.ReviewedBy, now, now,
	)
	if err == nil && app.Status == "approved" {
		// Update user role to provider if approved
		_, _ = r.q().ExecContext(ctx, "UPDATE public.app_users SET role = 'provider', updated_at = NOW() WHERE id = $1", app.UserID)
	}
	return err
}

// -----------------------------------------------------------------------------
// 5. Services & Categories (Unlimited Hierarchical Nesting)
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) ListCategories(ctx context.Context) ([]*models.ServiceCategory, error) {
	query := `
		SELECT id, parent_id, name, slug, description, icon_url, is_active, 
		       sort_order, category_type, allow_listings, created_at, updated_at
		FROM public.service_categories
		ORDER BY sort_order ASC, name ASC
	`
	rows, err := r.q().QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var all []*models.ServiceCategory
	for rows.Next() {
		c := &models.ServiceCategory{}
		if err := rows.Scan(
			&c.ID, &c.ParentID, &c.Name, &c.Slug, &c.Description, &c.IconURL,
			&c.IsActive, &c.SortOrder, &c.CategoryType, &c.AllowListings,
			&c.CreatedAt, &c.UpdatedAt,
		); err != nil {
			return nil, err
		}
		c.Children = []*models.ServiceCategory{}
		all = append(all, c)
	}

	return all, nil
}

func (r *pgAdminRepo) CreateCategory(ctx context.Context, cat *models.ServiceCategory) error {
	query := `
		INSERT INTO public.service_categories (
			id, parent_id, name, slug, description, icon_url, is_active, sort_order, category_type, allow_listings, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	if cat.ID == uuid.Nil {
		cat.ID = uuid.New()
	}
	now := time.Now().UTC()
	cat.CreatedAt = now
	cat.UpdatedAt = now

	_, err := r.q().ExecContext(ctx, query,
		cat.ID, cat.ParentID, cat.Name, cat.Slug, cat.Description, cat.IconURL,
		cat.IsActive, cat.SortOrder, cat.CategoryType, cat.AllowListings,
		cat.CreatedAt, cat.UpdatedAt,
	)
	return err
}

func (r *pgAdminRepo) UpdateCategory(ctx context.Context, cat *models.ServiceCategory) error {
	query := `
		UPDATE public.service_categories
		SET parent_id = $2, name = $3, slug = $4, description = $5, icon_url = $6,
		    is_active = $7, sort_order = $8, category_type = $9, allow_listings = $10, updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.q().ExecContext(ctx, query,
		cat.ID, cat.ParentID, cat.Name, cat.Slug, cat.Description, cat.IconURL,
		cat.IsActive, cat.SortOrder, cat.CategoryType, cat.AllowListings,
	)
	return err
}

func (r *pgAdminRepo) DeleteCategory(ctx context.Context, id uuid.UUID) error {
	_, err := r.q().ExecContext(ctx, "DELETE FROM public.service_categories WHERE id = $1", id)
	return err
}

// -----------------------------------------------------------------------------
// 6. Dynamic Form Definitions
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) GetFormDefinition(ctx context.Context, categoryID uuid.UUID) (*models.FormDefinition, error) {
	query := `
		SELECT id, category_id, title, description, status, version, schema, created_by, created_at, updated_at
		FROM public.form_definitions
		WHERE category_id = $1
		ORDER BY version DESC
		LIMIT 1
	`
	f := &models.FormDefinition{}
	var schemaBytes []byte
	err := r.q().QueryRowContext(ctx, query, categoryID).Scan(
		&f.ID, &f.CategoryID, &f.Title, &f.Description, &f.Status, &f.Version,
		&schemaBytes, &f.CreatedBy, &f.CreatedAt, &f.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	f.Schema = schemaBytes
	return f, nil
}

func (r *pgAdminRepo) SaveFormDefinition(ctx context.Context, form *models.FormDefinition) error {
	if form.ID == uuid.Nil {
		form.ID = uuid.New()
	}
	now := time.Now().UTC()
	form.CreatedAt = now
	form.UpdatedAt = now

	query := `
		INSERT INTO public.form_definitions (
			id, category_id, title, description, status, version, schema, created_by, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		ON CONFLICT (category_id, version) DO UPDATE SET
			title = EXCLUDED.title,
			description = EXCLUDED.description,
			status = EXCLUDED.status,
			schema = EXCLUDED.schema,
			updated_at = EXCLUDED.updated_at
	`
	_, err := r.q().ExecContext(ctx, query,
		form.ID, form.CategoryID, form.Title, form.Description, form.Status,
		form.Version, form.Schema, form.CreatedBy, form.CreatedAt, form.UpdatedAt,
	)
	return err
}

// -----------------------------------------------------------------------------
// 7. Products & Listings
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) ListListings(ctx context.Context, status string, limit, offset int) ([]*models.ProductListing, int64, error) {
	if limit <= 0 {
		limit = 20
	}
	statusClause := ""
	var args []interface{}
	argIdx := 1

	if status != "" {
		statusClause = fmt.Sprintf("WHERE pl.approval_status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}

	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM public.product_listings pl %s", statusClause)
	var total int64
	if err := r.q().QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := fmt.Sprintf(`
		SELECT pl.id, pl.vendor_id, COALESCE(u.full_name, ''), pl.category_id, COALESCE(sc.name, ''),
		       pl.title, pl.description, pl.listing_type, pl.unit_price, pl.pricing_unit,
		       pl.min_order_quantity, pl.has_transportation, pl.transportation_fee,
		       pl.is_active, pl.approval_status, pl.created_at, pl.updated_at
		FROM public.product_listings pl
		JOIN public.app_users u ON u.id = pl.vendor_id
		JOIN public.service_categories sc ON sc.id = pl.category_id
		%s
		ORDER BY pl.created_at DESC
		LIMIT $%d OFFSET $%d
	`, statusClause, argIdx, argIdx+1)

	args = append(args, limit, offset)
	rows, err := r.q().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*models.ProductListing
	for rows.Next() {
		pl := &models.ProductListing{}
		if err := rows.Scan(
			&pl.ID, &pl.VendorID, &pl.VendorName, &pl.CategoryID, &pl.CategoryName,
			&pl.Title, &pl.Description, &pl.ListingType, &pl.UnitPrice, &pl.PricingUnit,
			&pl.MinOrderQuantity, &pl.HasTransportation, &pl.TransportationFee,
			&pl.IsActive, &pl.ApprovalStatus, &pl.CreatedAt, &pl.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		list = append(list, pl)
	}

	return list, total, nil
}

func (r *pgAdminRepo) UpdateListingApproval(ctx context.Context, id uuid.UUID, status string) error {
	_, err := r.q().ExecContext(ctx, "UPDATE public.product_listings SET approval_status = $2, updated_at = NOW() WHERE id = $1", id, status)
	return err
}

func (r *pgAdminRepo) UpdateListingActiveStatus(ctx context.Context, id uuid.UUID, isActive bool) error {
	_, err := r.q().ExecContext(ctx, "UPDATE public.product_listings SET is_active = $2, updated_at = NOW() WHERE id = $1", id, isActive)
	return err
}

// -----------------------------------------------------------------------------
// 8. Bookings & Orders
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) ListOrders(ctx context.Context, status string, search string, limit, offset int) ([]*models.AdminOrder, int64, error) {
	if limit <= 0 {
		limit = 20
	}
	var conditions []string
	var args []interface{}
	argIdx := 1

	if status != "" {
		conditions = append(conditions, fmt.Sprintf("o.status = $%d", argIdx))
		args = append(args, status)
		argIdx++
	}

	if search != "" {
		conditions = append(conditions, fmt.Sprintf("(cu.full_name ILIKE $%d OR vu.full_name ILIKE $%d OR cu.phone LIKE $%d)", argIdx, argIdx, argIdx))
		args = append(args, "%"+search+"%")
		argIdx++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	countQuery := fmt.Sprintf(`
		SELECT COUNT(*) 
		FROM public.orders o
		JOIN public.app_users cu ON cu.id = o.customer_id
		JOIN public.app_users vu ON vu.id = o.vendor_id
		%s
	`, whereClause)

	var total int64
	if err := r.q().QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := fmt.Sprintf(`
		SELECT o.id, o.customer_id, cu.full_name, cu.phone, o.vendor_id, vu.full_name, vu.phone,
		       o.listing_id, COALESCE(pl.title, ''), o.status, o.total_amount, o.commission_amount,
		       o.order_details, o.dispute_reason, o.dispute_resolution, o.resolved_by, o.resolved_at,
		       o.created_at, o.updated_at
		FROM public.orders o
		JOIN public.app_users cu ON cu.id = o.customer_id
		JOIN public.app_users vu ON vu.id = o.vendor_id
		LEFT JOIN public.product_listings pl ON pl.id = o.listing_id
		%s
		ORDER BY o.created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argIdx, argIdx+1)

	args = append(args, limit, offset)
	rows, err := r.q().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*models.AdminOrder
	for rows.Next() {
		ao := &models.AdminOrder{}
		var details []byte
		var resBy *uuid.UUID
		if err := rows.Scan(
			&ao.ID, &ao.CustomerID, &ao.CustomerName, &ao.CustomerPhone,
			&ao.VendorID, &ao.VendorName, &ao.VendorPhone,
			&ao.ListingID, &ao.ListingTitle, &ao.Status, &ao.TotalAmount, &ao.CommissionAmount,
			&details, &ao.DisputeReason, &ao.DisputeResolution, &resBy, &ao.ResolvedAt,
			&ao.CreatedAt, &ao.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		ao.OrderDetails = details
		ao.ResolvedBy = resBy
		list = append(list, ao)
	}

	return list, total, nil
}

func (r *pgAdminRepo) GetOrder(ctx context.Context, id uuid.UUID) (*models.AdminOrder, error) {
	query := `
		SELECT o.id, o.customer_id, cu.full_name, cu.phone, o.vendor_id, vu.full_name, vu.phone,
		       o.listing_id, COALESCE(pl.title, ''), o.status, o.total_amount, o.commission_amount,
		       o.order_details, o.dispute_reason, o.dispute_resolution, o.resolved_by, o.resolved_at,
		       o.created_at, o.updated_at
		FROM public.orders o
		JOIN public.app_users cu ON cu.id = o.customer_id
		JOIN public.app_users vu ON vu.id = o.vendor_id
		LEFT JOIN public.product_listings pl ON pl.id = o.listing_id
		WHERE o.id = $1
	`
	ao := &models.AdminOrder{}
	var details []byte
	var resBy *uuid.UUID
	err := r.q().QueryRowContext(ctx, query, id).Scan(
		&ao.ID, &ao.CustomerID, &ao.CustomerName, &ao.CustomerPhone,
		&ao.VendorID, &ao.VendorName, &ao.VendorPhone,
		&ao.ListingID, &ao.ListingTitle, &ao.Status, &ao.TotalAmount, &ao.CommissionAmount,
		&details, &ao.DisputeReason, &ao.DisputeResolution, &resBy, &ao.ResolvedAt,
		&ao.CreatedAt, &ao.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	ao.OrderDetails = details
	ao.ResolvedBy = resBy
	return ao, nil
}

func (r *pgAdminRepo) UpdateOrderDispute(ctx context.Context, id uuid.UUID, resolution string, adminID uuid.UUID) error {
	now := time.Now().UTC()
	query := `
		UPDATE public.orders
		SET dispute_resolution = $2, resolved_by = $3, resolved_at = $4, status = 'completed', updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.q().ExecContext(ctx, query, id, resolution, adminID, now)
	return err
}

// -----------------------------------------------------------------------------
// 9. Requests & Quotations
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) ListQuotationRequests(ctx context.Context, status string, limit, offset int) ([]*models.QuotationRequest, int64, error) {
	if limit <= 0 {
		limit = 20
	}
	statusClause := ""
	var args []interface{}
	argIdx := 1

	if status != "" {
		statusClause = fmt.Sprintf("WHERE qr.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}

	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM public.quotation_requests qr %s", statusClause)
	var total int64
	if err := r.q().QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := fmt.Sprintf(`
		SELECT qr.id, qr.customer_id, COALESCE(u.full_name, ''), qr.category_id, COALESCE(sc.name, ''),
		       qr.title, qr.details, qr.status, qr.created_at, qr.updated_at
		FROM public.quotation_requests qr
		JOIN public.app_users u ON u.id = qr.customer_id
		LEFT JOIN public.service_categories sc ON sc.id = qr.category_id
		%s
		ORDER BY qr.created_at DESC
		LIMIT $%d OFFSET $%d
	`, statusClause, argIdx, argIdx+1)

	args = append(args, limit, offset)
	rows, err := r.q().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*models.QuotationRequest
	for rows.Next() {
		qr := &models.QuotationRequest{}
		var details []byte
		var catID *uuid.UUID
		if err := rows.Scan(
			&qr.ID, &qr.CustomerID, &qr.CustomerName, &catID, &qr.CategoryName,
			&qr.Title, &details, &qr.Status, &qr.CreatedAt, &qr.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		qr.CategoryID = catID
		qr.Details = details
		list = append(list, qr)
	}

	return list, total, nil
}

func (r *pgAdminRepo) GetQuotationRequest(ctx context.Context, id uuid.UUID) (*models.QuotationRequest, error) {
	query := `
		SELECT qr.id, qr.customer_id, COALESCE(u.full_name, ''), qr.category_id, COALESCE(sc.name, ''),
		       qr.title, qr.details, qr.status, qr.created_at, qr.updated_at
		FROM public.quotation_requests qr
		JOIN public.app_users u ON u.id = qr.customer_id
		LEFT JOIN public.service_categories sc ON sc.id = qr.category_id
		WHERE qr.id = $1
	`
	qr := &models.QuotationRequest{}
	var details []byte
	var catID *uuid.UUID
	err := r.q().QueryRowContext(ctx, query, id).Scan(
		&qr.ID, &qr.CustomerID, &qr.CustomerName, &catID, &qr.CategoryName,
		&qr.Title, &details, &qr.Status, &qr.CreatedAt, &qr.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	qr.CategoryID = catID
	qr.Details = details

	// Fetch bids
	bidQuery := `
		SELECT q.id, q.request_id, q.vendor_id, COALESCE(u.full_name, ''), q.offered_price, q.notes, q.status, q.created_at, q.updated_at
		FROM public.quotations q
		JOIN public.app_users u ON u.id = q.vendor_id
		WHERE q.request_id = $1
		ORDER BY q.created_at ASC
	`
	bRows, err := r.q().QueryContext(ctx, bidQuery, id)
	if err == nil {
		defer bRows.Close()
		for bRows.Next() {
			b := &models.Quotation{}
			_ = bRows.Scan(
				&b.ID, &b.RequestID, &b.VendorID, &b.VendorName, &b.OfferedPrice,
				&b.Notes, &b.Status, &b.CreatedAt, &b.UpdatedAt,
			)
			qr.Quotations = append(qr.Quotations, b)
		}
	}

	return qr, nil
}

// -----------------------------------------------------------------------------
// 10. Payments & Commission
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) ListPayments(ctx context.Context, paymentType, status string, limit, offset int) ([]*models.PaymentRecord, int64, error) {
	if limit <= 0 {
		limit = 20
	}
	var conditions []string
	var args []interface{}
	argIdx := 1

	if paymentType != "" {
		conditions = append(conditions, fmt.Sprintf("p.payment_type = $%d", argIdx))
		args = append(args, paymentType)
		argIdx++
	}
	if status != "" {
		conditions = append(conditions, fmt.Sprintf("p.status = $%d", argIdx))
		args = append(args, status)
		argIdx++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM public.payment_records p %s", whereClause)
	var total int64
	if err := r.q().QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := fmt.Sprintf(`
		SELECT p.id, p.order_id, p.payer_id, COALESCE(u.full_name, ''), p.amount, 
		       p.payment_type, p.status, p.reference_number, p.notes, p.created_at
		FROM public.payment_records p
		LEFT JOIN public.app_users u ON u.id = p.payer_id
		%s
		ORDER BY p.created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argIdx, argIdx+1)

	args = append(args, limit, offset)
	rows, err := r.q().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*models.PaymentRecord
	for rows.Next() {
		pr := &models.PaymentRecord{}
		if err := rows.Scan(
			&pr.ID, &pr.OrderID, &pr.PayerID, &pr.PayerName, &pr.Amount,
			&pr.PaymentType, &pr.Status, &pr.ReferenceNumber, &pr.Notes, &pr.CreatedAt,
		); err != nil {
			return nil, 0, err
		}
		list = append(list, pr)
	}

	return list, total, nil
}

func (r *pgAdminRepo) ListCommissionRules(ctx context.Context) ([]*models.CommissionRule, error) {
	query := `
		SELECT cr.id, cr.category_id, COALESCE(sc.name, 'Global Default'), cr.commission_percent, cr.fixed_fee, cr.is_active, cr.created_at, cr.updated_at
		FROM public.commission_rules cr
		LEFT JOIN public.service_categories sc ON sc.id = cr.category_id
		ORDER BY cr.created_at ASC
	`
	rows, err := r.q().QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*models.CommissionRule
	for rows.Next() {
		cr := &models.CommissionRule{}
		if err := rows.Scan(
			&cr.ID, &cr.CategoryID, &cr.CategoryName, &cr.CommissionPercent, &cr.FixedFee, &cr.IsActive, &cr.CreatedAt, &cr.UpdatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, cr)
	}
	return list, nil
}

func (r *pgAdminRepo) SetCommissionRule(ctx context.Context, rule *models.CommissionRule) error {
	if rule.ID == uuid.Nil {
		rule.ID = uuid.New()
	}
	now := time.Now().UTC()
	rule.CreatedAt = now
	rule.UpdatedAt = now

	query := `
		INSERT INTO public.commission_rules (id, category_id, commission_percent, fixed_fee, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (id) DO UPDATE SET
			commission_percent = EXCLUDED.commission_percent,
			fixed_fee = EXCLUDED.fixed_fee,
			is_active = EXCLUDED.is_active,
			updated_at = EXCLUDED.updated_at
	`
	_, err := r.q().ExecContext(ctx, query, rule.ID, rule.CategoryID, rule.CommissionPercent, rule.FixedFee, rule.IsActive, rule.CreatedAt, rule.UpdatedAt)
	return err
}

// -----------------------------------------------------------------------------
// 11. Audit Logs
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) CreateAuditLog(ctx context.Context, l *models.AuditLog) error {
	if l.ID == uuid.Nil {
		l.ID = uuid.New()
	}
	l.CreatedAt = time.Now().UTC()

	query := `
		INSERT INTO public.audit_logs (
			id, admin_id, admin_name, admin_role, action, entity_type, entity_id, old_values, new_values, ip_address, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`
	_, err := r.q().ExecContext(ctx, query,
		l.ID, l.AdminID, l.AdminName, l.AdminRole, l.Action, l.EntityType, l.EntityID,
		l.OldValues, l.NewValues, l.IPAddress, l.CreatedAt,
	)
	return err
}

func (r *pgAdminRepo) ListAuditLogs(ctx context.Context, entityType, action string, limit, offset int) ([]*models.AuditLog, int64, error) {
	if limit <= 0 {
		limit = 20
	}
	var conditions []string
	var args []interface{}
	argIdx := 1

	if entityType != "" {
		conditions = append(conditions, fmt.Sprintf("entity_type = $%d", argIdx))
		args = append(args, entityType)
		argIdx++
	}
	if action != "" {
		conditions = append(conditions, fmt.Sprintf("action = $%d", argIdx))
		args = append(args, action)
		argIdx++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM public.audit_logs %s", whereClause)
	var total int64
	if err := r.q().QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := fmt.Sprintf(`
		SELECT id, admin_id, admin_name, admin_role, action, entity_type, entity_id, old_values, new_values, ip_address, created_at
		FROM public.audit_logs
		%s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argIdx, argIdx+1)

	args = append(args, limit, offset)
	rows, err := r.q().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*models.AuditLog
	for rows.Next() {
		l := &models.AuditLog{}
		var oldV, newV []byte
		var aID *uuid.UUID
		if err := rows.Scan(
			&l.ID, &aID, &l.AdminName, &l.AdminRole, &l.Action, &l.EntityType, &l.EntityID,
			&oldV, &newV, &l.IPAddress, &l.CreatedAt,
		); err != nil {
			return nil, 0, err
		}
		l.AdminID = aID
		l.OldValues = oldV
		l.NewValues = newV
		list = append(list, l)
	}

	return list, total, nil
}

// -----------------------------------------------------------------------------
// 12. Settings
// -----------------------------------------------------------------------------

func (r *pgAdminRepo) GetSettings(ctx context.Context) (map[string]interface{}, error) {
	query := `SELECT key, value FROM public.system_settings`
	rows, err := r.q().QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	settings := make(map[string]interface{})
	for rows.Next() {
		var key string
		var valBytes []byte
		if err := rows.Scan(&key, &valBytes); err != nil {
			return nil, err
		}
		var parsed interface{}
		_ = json.Unmarshal(valBytes, &parsed)
		settings[key] = parsed
	}
	return settings, nil
}

func (r *pgAdminRepo) UpdateSetting(ctx context.Context, key string, val interface{}, adminID uuid.UUID) error {
	valBytes, err := json.Marshal(val)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO public.system_settings (key, value, updated_by, updated_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (key) DO UPDATE SET
			value = EXCLUDED.value,
			updated_by = EXCLUDED.updated_by,
			updated_at = NOW()
	`
	_, err = r.q().ExecContext(ctx, query, key, valBytes, adminID)
	return err
}
