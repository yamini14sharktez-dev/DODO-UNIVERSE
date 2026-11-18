package admin

import (
	"context"
	"testing"

	"dodo-universe-backend/internal/database"
	"dodo-universe-backend/internal/models"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

func setupTestService(t *testing.T) (Service, database.Store) {
	t.Helper()
	store := database.NewMemoryStore()
	svc := NewService(store, "test-jwt-secret-key-32-chars-long!", 60, 30)
	return svc, store
}

func TestAdminAuth_LoginAndLockout(t *testing.T) {
	svc, store := setupTestService(t)
	ctx := context.Background()

	hash, _ := bcrypt.GenerateFromPassword([]byte("Secret123!"), bcrypt.DefaultCost)
	admin := &models.AdminUser{
		ID:           uuid.New(),
		Email:        "super@dodouniverse.com",
		Phone:        "+919876543210",
		FullName:     "Chief Administrator",
		Role:         models.AdminRoleSuper,
		PasswordHash: string(hash),
		IsActive:     true,
	}
	if err := store.Admin().CreateAdmin(ctx, admin); err != nil {
		t.Fatalf("Failed to create admin: %v", err)
	}

	// 1. Successful login
	resp, err := svc.Login(ctx, "super@dodouniverse.com", "Secret123!", "127.0.0.1")
	if err != nil {
		t.Fatalf("Expected successful login, got: %v", err)
	}
	if resp.Tokens.AccessToken == "" || resp.Tokens.RefreshToken == "" {
		t.Fatalf("Expected tokens to be populated")
	}

	// 2. Failed login with wrong password
	_, err = svc.Login(ctx, "super@dodouniverse.com", "WrongPassword", "127.0.0.1")
	if err != ErrInvalidCredentials {
		t.Fatalf("Expected ErrInvalidCredentials, got: %v", err)
	}

	// 3. Failed attempts lockout (4 more failures -> 5 total)
	for i := 0; i < 4; i++ {
		_, _ = svc.Login(ctx, "super@dodouniverse.com", "WrongPassword", "127.0.0.1")
	}

	// 4. Now locked out
	_, err = svc.Login(ctx, "super@dodouniverse.com", "Secret123!", "127.0.0.1")
	if err != ErrAdminLocked {
		t.Fatalf("Expected ErrAdminLocked after 5 failures, got: %v", err)
	}
}

func TestAdminAuth_RefreshTokenAndLogout(t *testing.T) {
	svc, store := setupTestService(t)
	ctx := context.Background()

	hash, _ := bcrypt.GenerateFromPassword([]byte("Secret123!"), bcrypt.DefaultCost)
	admin := &models.AdminUser{
		ID:           uuid.New(),
		Email:        "ops@dodouniverse.com",
		Phone:        "+919876543211",
		FullName:     "Operations Admin",
		Role:         models.AdminRoleOperations,
		PasswordHash: string(hash),
		IsActive:     true,
	}
	_ = store.Admin().CreateAdmin(ctx, admin)

	resp, err := svc.Login(ctx, "ops@dodouniverse.com", "Secret123!", "127.0.0.1")
	if err != nil {
		t.Fatalf("Login failed: %v", err)
	}

	// Refresh token
	newTokens, err := svc.RefreshToken(ctx, resp.Tokens.RefreshToken)
	if err != nil {
		t.Fatalf("RefreshToken failed: %v", err)
	}
	if newTokens.AccessToken == "" {
		t.Fatalf("Expected new access token")
	}

	// Old refresh token must now be revoked
	_, err = svc.RefreshToken(ctx, resp.Tokens.RefreshToken)
	if err == nil {
		t.Fatalf("Expected old refresh token to fail after rotation")
	}

	// Logout with new token
	if err := svc.Logout(ctx, newTokens.RefreshToken); err != nil {
		t.Fatalf("Logout failed: %v", err)
	}

	// Token must be revoked after logout
	_, err = svc.RefreshToken(ctx, newTokens.RefreshToken)
	if err == nil {
		t.Fatalf("Expected token to fail after logout")
	}
}

func TestAdmin_CategoriesHierarchy(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	actor := &models.AdminClaims{
		AdminID:  uuid.New().String(),
		FullName: "Super Admin",
		Role:     models.AdminRoleSuper,
	}

	// Create root category (Bricks)
	root, err := svc.CreateCategory(ctx, &models.ServiceCategory{
		Name:         "Bricks",
		CategoryType: "container",
	}, actor, "127.0.0.1")
	if err != nil {
		t.Fatalf("Failed to create root category: %v", err)
	}

	// Create level 1 child (Red Clay Bricks)
	child1, err := svc.CreateCategory(ctx, &models.ServiceCategory{
		ParentID:     &root.ID,
		Name:         "Red Clay Bricks",
		CategoryType: "product_category",
	}, actor, "127.0.0.1")
	if err != nil {
		t.Fatalf("Failed to create child 1: %v", err)
	}

	// Create level 2 child (Material + Transportation)
	_, err = svc.CreateCategory(ctx, &models.ServiceCategory{
		ParentID:      &child1.ID,
		Name:          "Material + Transportation",
		CategoryType:  "bookable_service",
		AllowListings: true,
	}, actor, "127.0.0.1")
	if err != nil {
		t.Fatalf("Failed to create child 2: %v", err)
	}

	// Verify tree hierarchy
	tree, err := svc.ListCategoriesTree(ctx)
	if err != nil {
		t.Fatalf("Failed to list tree: %v", err)
	}

	if len(tree) != 1 {
		t.Fatalf("Expected 1 root category, got %d", len(tree))
	}
	if len(tree[0].Children) != 1 {
		t.Fatalf("Expected 1 level-1 child, got %d", len(tree[0].Children))
	}
	if len(tree[0].Children[0].Children) != 1 {
		t.Fatalf("Expected 1 level-2 child, got %d", len(tree[0].Children[0].Children))
	}
}

func TestAdmin_DashboardMetricsZeroFakeData(t *testing.T) {
	svc, _ := setupTestService(t)
	ctx := context.Background()

	// Metrics on empty database must return exact 0 values, never fabricated numbers
	metrics, err := svc.GetMetrics(ctx)
	if err != nil {
		t.Fatalf("Failed to get metrics: %v", err)
	}

	if metrics.TotalPeople != 0 {
		t.Fatalf("Expected TotalPeople=0, got %d", metrics.TotalPeople)
	}
	if metrics.TotalOrders != 0 {
		t.Fatalf("Expected TotalOrders=0, got %d", metrics.TotalOrders)
	}
	if metrics.ActiveVendors != 0 {
		t.Fatalf("Expected ActiveVendors=0, got %d", metrics.ActiveVendors)
	}
}
