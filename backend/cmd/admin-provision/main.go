package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"flag"
	"fmt"
	"log"
	"strings"
	"time"

	"dodo-universe-backend/internal/config"
	"dodo-universe-backend/internal/database"
	"dodo-universe-backend/internal/models"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	emailFlag := flag.String("email", "admin@dodouniverse.com", "Admin email address")
	phoneFlag := flag.String("phone", "+919999999999", "Admin phone number")
	nameFlag := flag.String("name", "Super Administrator", "Admin full name")
	passFlag := flag.String("password", "", "Admin password (generated automatically if omitted)")
	roleFlag := flag.String("role", "super_admin", "Admin role (super_admin, operations_admin, finance_admin)")
	flag.Parse()

	if err := config.LoadEnv(); err != nil {
		log.Printf("Notice: could not load .env: %v", err)
	}

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Configuration error: %v", err)
	}

	password := strings.TrimSpace(*passFlag)
	if password == "" {
		bytes := make([]byte, 8)
		_, _ = rand.Read(bytes)
		password = "Admin@" + hex.EncodeToString(bytes) + "!"
	}

	var store database.Store
	if cfg.UseMemoryStore || cfg.StorageType == "memory" {
		fmt.Println("Running with in-memory store...")
		store = database.NewMemoryStore()
	} else if cfg.DatabaseURL != "" {
		fmt.Println("Connecting to PostgreSQL database...")
		store, err = database.NewPostgresStore(cfg.DatabaseURL)
		if err != nil {
			log.Fatalf("Failed to connect to PostgreSQL: %v", err)
		}
	} else {
		fmt.Println("No DATABASE_URL configured. Running with in-memory store...")
		store = database.NewMemoryStore()
	}
	defer store.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("Failed to hash password: %v", err)
	}

	role := models.AdminRole(*roleFlag)
	existing, err := store.Admin().FindAdminByEmailOrPhone(ctx, *emailFlag)
	if err == nil && existing != nil {
		existing.PasswordHash = string(hash)
		existing.Role = role
		existing.IsActive = true
		existing.FullName = *nameFlag
		existing.Phone = *phoneFlag
		if err := store.Admin().UpdateAdmin(ctx, existing); err != nil {
			log.Fatalf("Failed to update admin: %v", err)
		}
		printSuccess("UPDATED EXISTING ADMIN", existing.Email, existing.Phone, password, string(role))
		return
	}

	newAdmin := &models.AdminUser{
		ID:           uuid.New(),
		Email:        *emailFlag,
		Phone:        *phoneFlag,
		FullName:     *nameFlag,
		PasswordHash: string(hash),
		Role:         role,
		IsActive:     true,
	}

	if err := store.Admin().CreateAdmin(ctx, newAdmin); err != nil {
		log.Fatalf("Failed to create admin: %v", err)
	}

	printSuccess("CREATED NEW SUPER ADMIN", newAdmin.Email, newAdmin.Phone, password, string(role))
}

func printSuccess(title, email, phone, password, role string) {
	fmt.Println("\n" + strings.Repeat("=", 60))
	fmt.Printf("   DODO UNIVERSE ADMIN PROVISIONING: %s\n", title)
	fmt.Println(strings.Repeat("=", 60))
	fmt.Printf("   Role:        %s\n", role)
	fmt.Printf("   Email:       %s\n", email)
	fmt.Printf("   Phone:       %s\n", phone)
	fmt.Printf("   Password:    %s\n", password)
	fmt.Println(strings.Repeat("=", 60))
	fmt.Println("   IMPORTANT: Store these credentials in a secure password manager.")
}
