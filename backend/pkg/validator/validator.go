package validator

import (
	"errors"
	"regexp"
	"strings"
)

var (
	emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	otpRegex   = regexp.MustCompile(`^\d{6}$`)
)

// ValidateName checks that a name is at least 2 characters.
func ValidateName(name string) (string, error) {
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		return "", errors.New("full name is required")
	}
	if len(trimmed) < 2 {
		return "", errors.New("name must be at least 2 characters")
	}
	return trimmed, nil
}

// ValidateAndFormatIndianPhone normalizes and validates a 10-digit Indian phone number to E.164 (+91XXXXXXXXXX).
func ValidateAndFormatIndianPhone(phone string) (string, error) {
	// Strip all non-digit characters
	re := regexp.MustCompile(`\D`)
	digits := re.ReplaceAllString(phone, "")

	if len(digits) == 10 {
		if digits[0] < '6' || digits[0] > '9' {
			return "", errors.New("Indian mobile number must start with 6, 7, 8, or 9")
		}
		return "+91" + digits, nil
	} else if len(digits) == 12 && strings.HasPrefix(digits, "91") {
		sub := digits[2:]
		if sub[0] < '6' || sub[0] > '9' {
			return "", errors.New("Indian mobile number must start with 6, 7, 8, or 9")
		}
		return "+91" + sub, nil
	}

	return "", errors.New("please enter a valid 10-digit Indian mobile number")
}

// ValidateEmail checks email syntax.
func ValidateEmail(email string) (string, error) {
	trimmed := strings.ToLower(strings.TrimSpace(email))
	if trimmed == "" {
		return "", errors.New("email address is required")
	}
	if !emailRegex.MatchString(trimmed) {
		return "", errors.New("please enter a valid email address")
	}
	return trimmed, nil
}

// ValidateOTP validates a 6-digit numeric OTP.
func ValidateOTP(otp string) (string, error) {
	trimmed := strings.TrimSpace(otp)
	if !otpRegex.MatchString(trimmed) {
		return "", errors.New("OTP must be a 6-digit number")
	}
	return trimmed, nil
}

