package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"dodo-universe-backend/internal/admin"
	"dodo-universe-backend/internal/auth"
	"dodo-universe-backend/internal/config"
	"dodo-universe-backend/internal/database"
	"dodo-universe-backend/internal/middleware"
	"dodo-universe-backend/internal/notification"
	"dodo-universe-backend/internal/order"
	"dodo-universe-backend/internal/payment"
	"dodo-universe-backend/internal/provider"
	"dodo-universe-backend/internal/requestquote"
	"dodo-universe-backend/internal/servicemgmt"
	"dodo-universe-backend/internal/user"
	"dodo-universe-backend/pkg/response"
)

func main() {
	if err := config.LoadEnv(); err != nil && !errors.Is(err, os.ErrNotExist) {
		log.Printf("Notice: could not load root .env file: %v", err)
	}

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("FATAL: Configuration error: %v", err)
	}

	log.Printf("Starting DODO Universe Backend [%s mode] on port %s...", cfg.Environment, cfg.Port)

	// Database initialization
	var store database.Store

	if cfg.UseMemoryStore {
		log.Println("Explicit in-memory store requested (STORAGE_TYPE=memory or USE_MEMORY_STORE=true).")
		store = database.NewMemoryStore()
	} else if cfg.DatabaseURL != "" {
		log.Println("Connecting to PostgreSQL database...")
		store, err = database.NewPostgresStore(cfg.DatabaseURL)
		if err != nil {
			log.Fatalf("FATAL: Failed to connect to PostgreSQL: %v", err)
		}
		log.Println("Connected to PostgreSQL successfully.")
	} else {
		if cfg.IsProduction() {
			log.Fatalf("FATAL: DATABASE_URL must be specified in production mode.")
		}
		if cfg.StorageType == "postgres" {
			log.Fatalf("FATAL: STORAGE_TYPE is set to 'postgres' but DATABASE_URL is empty.")
		}
		log.Println("No DATABASE_URL configured in development. Running with in-memory database store.")
		store = database.NewMemoryStore()
	}
	defer store.Close()

	// Auth token manager and OTP provider
	tokenManager := auth.NewTokenManager(cfg.JWTSecret, cfg.JWTExpiryMinutes, cfg.RefreshExpiryDays)
	devRecorder := auth.NewInMemDeliveryRecorder()
	otpProvider := auth.NewOTPProvider(cfg.IsDevelopment(), cfg.DevOTP, store.DevTestNumbers(), nil, nil, devRecorder)
	authMiddleware := middleware.Authenticate(cfg.JWTSecret)

	// Core domain services
	authSvc := auth.NewService(store, tokenManager, otpProvider, cfg.IsDevelopment())
	userSvc := user.NewService(store)
	providerSvc := provider.NewService(store)
	serviceMgmtSvc := servicemgmt.NewService()
	orderSvc := order.NewService()
	requestQuoteSvc := requestquote.NewService()
	notificationSvc := notification.NewService()
	paymentSvc := payment.NewService()
	adminSvc := admin.NewService()

	// HTTP Multiplexer
	mux := http.NewServeMux()

	// 1. Health checks
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		response.OK(w, map[string]interface{}{
			"status":      "healthy",
			"environment": cfg.Environment,
			"timestamp":   time.Now().UTC().Format(time.RFC3339),
			"database":    checkDB(store),
		})
	})
	mux.HandleFunc("GET /livez", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if err := store.Ping(r.Context()); err != nil {
			response.Error(w, http.StatusServiceUnavailable, "UNREADY", "Database not ready")
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})

	// 2. Register Microservice Handlers
	auth.NewHandler(authSvc).RegisterRoutes(mux, authMiddleware)
	user.NewHandler(userSvc).RegisterRoutes(mux, authMiddleware)
	provider.NewHandler(providerSvc).RegisterRoutes(mux, authMiddleware)
	servicemgmt.NewHandler(serviceMgmtSvc).RegisterRoutes(mux)
	order.NewHandler(orderSvc).RegisterRoutes(mux, authMiddleware)
	requestquote.NewHandler(requestQuoteSvc).RegisterRoutes(mux, authMiddleware)
	notification.NewHandler(notificationSvc).RegisterRoutes(mux, authMiddleware)
	payment.NewHandler(paymentSvc).RegisterRoutes(mux, authMiddleware)
	admin.NewHandler(adminSvc).RegisterRoutes(mux, authMiddleware)

	// Apply Middlewares in chain: CORS -> Logger -> Recoverer -> mux
	handler := middleware.CORS(cfg.AllowedOrigins)(mux)
	handler = middleware.Logger(handler)
	handler = middleware.Recoverer(handler)

	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown handling
	serverErrors := make(chan error, 1)
	go func() {
		log.Printf("DODO Universe Backend listening on http://localhost:%s", cfg.Port)
		serverErrors <- server.ListenAndServe()
	}()

	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	select {
	case err := <-serverErrors:
		if err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server stopped with error: %v", err)
		}
	case sig := <-shutdown:
		log.Printf("Caught signal %v, initiating graceful shutdown...", sig)
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			log.Printf("Server shutdown error: %v, forcing close", err)
			_ = server.Close()
		}
		log.Println("Server exited cleanly.")
	}
}

func checkDB(store database.Store) string {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()
	if err := store.Ping(ctx); err != nil {
		return "degraded"
	}
	return "connected"
}
