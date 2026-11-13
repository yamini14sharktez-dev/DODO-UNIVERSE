package config

import (
	"os"
	"testing"
)

func TestConfigValidationStorageTypePostgresWithoutURL(t *testing.T) {
	cfg := &Config{
		Environment:    "development",
		StorageType:    "postgres",
		DatabaseURL:    "",
		UseMemoryStore: false,
	}

	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected validation error when STORAGE_TYPE is 'postgres' but DatabaseURL is empty")
	}
}

func TestConfigValidationConflictingStorageSettings(t *testing.T) {
	cfg := &Config{
		Environment:    "development",
		StorageType:    "memory",
		DatabaseURL:    "postgresql://localhost:5432/dodo",
		UseMemoryStore: true,
	}

	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected validation error when DatabaseURL is set but UseMemoryStore is true")
	}
}

func TestConfigValidationProductionConstraints(t *testing.T) {
	cfg := &Config{
		Environment:    "production",
		DatabaseURL:    "",
		StorageType:    "postgres",
		JWTSecret:      "short",
		AllowedOrigins: []string{"*"},
	}

	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected validation error for invalid production config")
	}
}

func TestLoadDefaults(t *testing.T) {
	// Clear relevant env vars
	_ = os.Unsetenv("DATABASE_URL")
	_ = os.Unsetenv("STORAGE_TYPE")
	_ = os.Unsetenv("USE_MEMORY_STORE")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() failed: %v", err)
	}

	if cfg.Port != "8080" {
		t.Errorf("expected default port 8080, got %s", cfg.Port)
	}
	if cfg.DevOTP != "123456" {
		t.Errorf("expected default DevOTP '123456', got %s", cfg.DevOTP)
	}
}

