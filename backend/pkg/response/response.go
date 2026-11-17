package response

import (
	"encoding/json"
	"net/http"
)

// Response represents a standard JSON API envelope.
type Response struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   *APIError   `json:"error,omitempty"`
}

// APIError contains structured error details.
type APIError struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

// JSON sends a JSON response with the provided status code.
func JSON(w http.ResponseWriter, statusCode int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(data)
}

// OK sends a 200 OK success response.
func OK(w http.ResponseWriter, data interface{}, message ...string) {
	msg := ""
	if len(message) > 0 {
		msg = message[0]
	}
	JSON(w, http.StatusOK, Response{
		Success: true,
		Message: msg,
		Data:    data,
	})
}

// Created sends a 201 Created success response.
func Created(w http.ResponseWriter, data interface{}, message ...string) {
	msg := ""
	if len(message) > 0 {
		msg = message[0]
	}
	JSON(w, http.StatusCreated, Response{
		Success: true,
		Message: msg,
		Data:    data,
	})
}

// Error sends an error response with appropriate HTTP status.
func Error(w http.ResponseWriter, statusCode int, code, message string, details ...interface{}) {
	var detail interface{}
	if len(details) > 0 {
		detail = details[0]
	}
	JSON(w, statusCode, Response{
		Success: false,
		Error: &APIError{
			Code:    code,
			Message: message,
			Details: detail,
		},
	})
}

// BadRequest sends a 400 Bad Request error.
func BadRequest(w http.ResponseWriter, message string, code ...string) {
	c := "BAD_REQUEST"
	if len(code) > 0 {
		c = code[0]
	}
	Error(w, http.StatusBadRequest, c, message)
}

// Unauthorized sends a 401 Unauthorized error.
func Unauthorized(w http.ResponseWriter, message string, code ...string) {
	c := "UNAUTHORIZED"
	if len(code) > 0 {
		c = code[0]
	}
	Error(w, http.StatusUnauthorized, c, message)
}

// Forbidden sends a 403 Forbidden error.
func Forbidden(w http.ResponseWriter, message string, code ...string) {
	c := "FORBIDDEN"
	if len(code) > 0 {
		c = code[0]
	}
	Error(w, http.StatusForbidden, c, message)
}

// NotFound sends a 404 Not Found error.
func NotFound(w http.ResponseWriter, message string, code ...string) {
	c := "NOT_FOUND"
	if len(code) > 0 {
		c = code[0]
	}
	Error(w, http.StatusNotFound, c, message)
}

// InternalServerError sends a 500 Internal Server Error.
func InternalServerError(w http.ResponseWriter, message string) {
	Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", message)
}

