package config

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// FindRootEnvFile searches for the project-root .env file.
// It resolves the file in the following order:
// 1. Path specified in ENV_FILE environment variable, if set and valid.
// 2. Upward directory walk starting from current working directory (os.Getwd).
// 3. Upward directory walk starting from executable directory (os.Executable).
//
// A directory is identified as the project root if it contains ".env" along with
// project root markers ("PROJECT_GUIDE.md", "backend", or ".git").
func FindRootEnvFile() (string, error) {
	if explicit := os.Getenv("ENV_FILE"); explicit != "" {
		if fi, err := os.Stat(explicit); err == nil && !fi.IsDir() {
			return filepath.Abs(explicit)
		}
	}

	// 1. Search upward from working directory (e.g. C:\DODO-Uni or C:\DODO-Uni\backend)
	if cwd, err := os.Getwd(); err == nil {
		if path := findEnvUpward(cwd); path != "" {
			return path, nil
		}
	}

	// 2. Search upward from executable directory
	if exePath, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exePath)
		if path := findEnvUpward(exeDir); path != "" {
			return path, nil
		}
	}

	return "", os.ErrNotExist
}

// findEnvUpward checks directory and parent directories (up to 8 levels) for a project .env file.
func findEnvUpward(startDir string) string {
	curr, err := filepath.Abs(startDir)
	if err != nil {
		curr = startDir
	}

	var fallbackCandidate string

	for i := 0; i < 8; i++ {
		envCandidate := filepath.Join(curr, ".env")
		if fi, err := os.Stat(envCandidate); err == nil && !fi.IsDir() {
			// Prioritize the directory if it is clearly the project root
			if isProjectRoot(curr) {
				return envCandidate
			}
			if fallbackCandidate == "" {
				fallbackCandidate = envCandidate
			}
		}

		parent := filepath.Dir(curr)
		if parent == curr {
			break
		}
		curr = parent
	}

	return fallbackCandidate
}

// isProjectRoot checks for key marker files/directories that uniquely identify the DODO Universe project root.
func isProjectRoot(dir string) bool {
	markers := []string{"PROJECT_GUIDE.md", "backend", ".git"}
	for _, m := range markers {
		if _, err := os.Stat(filepath.Join(dir, m)); err == nil {
			return true
		}
	}
	return false
}

// LoadEnv discovers and loads the project root .env file into the environment.
// Existing environment variables are strictly preserved and never overwritten.
// No variable values or secrets are ever printed or logged.
func LoadEnv() error {
	path, err := FindRootEnvFile()
	if err != nil {
		return err
	}
	return LoadEnvFile(path)
}

// LoadEnvFile parses a specific .env file and sets variables in the environment.
// It preserves any existing environment variables (does not overwrite).
func LoadEnvFile(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	vars, err := ParseEnv(f)
	if err != nil {
		return fmt.Errorf("failed to parse env file: %w", err)
	}

	for k, v := range vars {
		// Strictly preserve existing environment variables; do NOT overwrite
		if _, exists := os.LookupEnv(k); !exists {
			if err := os.Setenv(k, v); err != nil {
				return fmt.Errorf("failed to set environment variable: %w", err)
			}
		}
	}

	return nil
}

// ParseEnv parses standard .env formatted key-value pairs from a reader.
// Supports:
// - comments starting with #
// - empty lines and whitespace trimming
// - optional 'export ' prefix
// - double-quoted and single-quoted values
// - escape sequences (\n, \r, \t, \", \\) inside double quotes
// - inline comments for unquoted values
func ParseEnv(r io.Reader) (map[string]string, error) {
	scanner := bufio.NewScanner(r)
	result := make(map[string]string)
	isFirstLine := true

	for scanner.Scan() {
		line := scanner.Text()

		// Strip UTF-8 BOM if present on first line
		if isFirstLine {
			line = strings.TrimPrefix(line, "\ufeff")
			isFirstLine = false
		}

		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Strip 'export ' prefix if present
		line = strings.TrimPrefix(line, "export ")
		line = strings.TrimSpace(line)

		eqIdx := strings.Index(line, "=")
		if eqIdx == -1 {
			continue
		}

		key := strings.TrimSpace(line[:eqIdx])
		if key == "" {
			continue
		}

		rawVal := strings.TrimSpace(line[eqIdx+1:])
		val := parseEnvValue(rawVal)

		result[key] = val
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return result, nil
}

func parseEnvValue(raw string) string {
	if len(raw) >= 2 {
		if raw[0] == '"' && raw[len(raw)-1] == '"' {
			inner := raw[1 : len(raw)-1]
			inner = strings.ReplaceAll(inner, `\"`, `"`)
			inner = strings.ReplaceAll(inner, `\n`, "\n")
			inner = strings.ReplaceAll(inner, `\r`, "\r")
			inner = strings.ReplaceAll(inner, `\t`, "\t")
			inner = strings.ReplaceAll(inner, `\\`, `\`)
			return inner
		}
		if raw[0] == '\'' && raw[len(raw)-1] == '\'' {
			return raw[1 : len(raw)-1]
		}
	}

	// Unquoted value: check for trailing inline comment
	if commentIdx := strings.Index(raw, " #"); commentIdx != -1 {
		raw = strings.TrimSpace(raw[:commentIdx])
	} else if commentIdx := strings.Index(raw, "\t#"); commentIdx != -1 {
		raw = strings.TrimSpace(raw[:commentIdx])
	}

	return raw
}

