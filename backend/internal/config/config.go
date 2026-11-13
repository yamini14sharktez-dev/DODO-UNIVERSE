package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config holds all backend runtime configuration loaded from environment variables.
type Config struct {
	Port              string
	Environment       string
	DatabaseURL       string
	StorageType       string // "postgres", "memory", or "auto"
	UseMemoryStore    bool
	JWTSecret         string
	JWTExpiryMinutes  int
	RefreshExpiryDays int
	DevOTP            string
	AllowedOrigins    []string
}

// Load reads configuration from environment variables with safe development defaults.
// Automatically discovers and loads the project root .env file if available,
// preserving all existing environment variables.
func Load() (*Config, error) {
	_ = LoadEnv()

	env := strings.ToLower(strings.TrimSpace(getEnv("ENVIRONMENT", "development")))

	jwtExpiry, _ := strconv.Atoi(getEnv("JWT_EXPIRY_MINUTES", "60"))
	if jwtExpiry <= 0 {
		jwtExpiry = 60
	}

	refreshExpiry, _ := strconv.Atoi(getEnv("REFRESH_EXPIRY_DAYS", "30"))
	if refreshExpiry <= 0 {
		refreshExpiry = 30
	}

	storageType := strings.ToLower(strings.TrimSpace(getEnv("STORAGE_TYPE", "auto")))
	useMemory := storageType == "memory" || strings.ToLower(strings.TrimSpace(getEnv("USE_MEMORY_STORE", "false"))) == "true"

	originsRaw := getEnv("ALLOWED_ORIGINS", "*")
	var origins []string
	for _, o := range strings.Split(originsRaw, ",") {
		trimmed := strings.TrimSpace(o)
		if trimmed != "" {
			origins = append(origins, trimmed)
		}
	}
	if len(origins) == 0 {
		origins = []string{"*"}
	}

	jwtSecret := getEnv("JWT_SECRET", "")
	if jwtSecret == "" {
		if env == "production" || env == "prod" {
			return nil, errors.New("JWT_SECRET environment variable is required in production")
		}
		jwtSecret = "dodo-universe-dev-insecure-jwt-secret-key-32b!"
	}

	cfg := &Config{
		Port:              getEnv("PORT", "8080"),
		Environment:       env,
		DatabaseURL:       getEnv("DATABASE_URL", ""),
		StorageType:       storageType,
		UseMemoryStore:    useMemory,
		JWTSecret:         jwtSecret,
		JWTExpiryMinutes:  jwtExpiry,
		RefreshExpiryDays: refreshExpiry,
		DevOTP:            getEnv("DEV_OTP", "123456"),
		AllowedOrigins:    origins,
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// Validate checks whether configuration complies with environment safety constraints.
func (c *Config) Validate() error {
	if c.StorageType == "postgres" && c.DatabaseURL == "" {
		return errors.New("DATABASE_URL is required when STORAGE_TYPE is set to 'postgres'")
	}
	if c.DatabaseURL != "" && (c.UseMemoryStore || c.StorageType == "memory") {
		return errors.New("conflicting database configuration: DATABASE_URL is configured but STORAGE_TYPE is 'memory' or USE_MEMORY_STORE is true")
	}

	if c.IsProduction() {
		if c.DatabaseURL == "" {
			return errors.New("DATABASE_URL is required in production")
		}
		if c.UseMemoryStore || c.StorageType == "memory" {
			return errors.New("in-memory store cannot be used in production")
		}
		if len(c.JWTSecret) < 32 {
			return fmt.Errorf("JWT_SECRET must be at least 32 characters in production (got %d)", len(c.JWTSecret))
		}
		for _, o := range c.AllowedOrigins {
			if o == "*" {
				return errors.New("wildcard CORS origin '*' is not permitted in production")
			}
		}
	}
	return nil
}

// IsDevelopment returns true if running in development mode.
func (c *Config) IsDevelopment() bool {
	return c.Environment == "development" || c.Environment == "dev" || c.Environment == "test"
}

// IsProduction returns true if running in production mode.
func (c *Config) IsProduction() bool {
	return c.Environment == "production" || c.Environment == "prod"
}

func getEnv(key, fallback string) string {
	if val, ok := os.LookupEnv(key); ok && strings.TrimSpace(val) != "" {
		return strings.TrimSpace(val)
	}
	return fallback
}
