package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseEnv(t *testing.T) {
	input := `# Comment line
ENVIRONMENT=test
export PORT=9090
DB_URL="postgresql://user:secret@localhost:5432/db?sslmode=disable"
SINGLE_QUOTED='literal_value$with#special'
WITH_INLINE_COMMENT=active # This is an inline comment
EMPTY_KEY=
`
	vars, err := ParseEnv(strings.NewReader(input))
	if err != nil {
		t.Fatalf("ParseEnv returned unexpected error: %v", err)
	}

	expected := map[string]string{
		"ENVIRONMENT":         "test",
		"PORT":                "9090",
		"DB_URL":              "postgresql://user:secret@localhost:5432/db?sslmode=disable",
		"SINGLE_QUOTED":       "literal_value$with#special",
		"WITH_INLINE_COMMENT": "active",
		"EMPTY_KEY":           "",
	}

	for k, want := range expected {
		got, ok := vars[k]
		if !ok {
			t.Errorf("expected key %q not found in parsed result", k)
			continue
		}
		if got != want {
			t.Errorf("for key %q, got %q, want %q", k, got, want)
		}
	}
}

func TestParseEnvWithBOM(t *testing.T) {
	input := "\ufeffENVIRONMENT=staging\nPORT=8081\n"
	vars, err := ParseEnv(strings.NewReader(input))
	if err != nil {
		t.Fatalf("ParseEnv with BOM returned error: %v", err)
	}

	if vars["ENVIRONMENT"] != "staging" {
		t.Errorf("expected ENVIRONMENT='staging', got %q", vars["ENVIRONMENT"])
	}
	if vars["PORT"] != "8081" {
		t.Errorf("expected PORT='8081', got %q", vars["PORT"])
	}
}

func TestLoadEnvFilePreservesExistingEnv(t *testing.T) {
	tmpDir := t.TempDir()
	envPath := filepath.Join(tmpDir, ".env")

	content := "PREEXISTING_KEY=new_val\nNEW_KEY=set_from_file\n"
	if err := os.WriteFile(envPath, []byte(content), 0600); err != nil {
		t.Fatalf("failed to write temp env file: %v", err)
	}

	// Set preexisting key in OS environment
	const initialVal = "do_not_overwrite"
	_ = os.Setenv("PREEXISTING_KEY", initialVal)
	_ = os.Unsetenv("NEW_KEY")
	defer os.Unsetenv("PREEXISTING_KEY")
	defer os.Unsetenv("NEW_KEY")

	if err := LoadEnvFile(envPath); err != nil {
		t.Fatalf("LoadEnvFile failed: %v", err)
	}

	// Verify PREEXISTING_KEY was preserved and not overwritten
	if got := os.Getenv("PREEXISTING_KEY"); got != initialVal {
		t.Errorf("expected PREEXISTING_KEY to remain %q, but got %q", initialVal, got)
	}

	// Verify NEW_KEY was populated from file
	if got := os.Getenv("NEW_KEY"); got != "set_from_file" {
		t.Errorf("expected NEW_KEY to be %q, but got %q", "set_from_file", got)
	}
}

func TestFindRootEnvFile(t *testing.T) {
	// 1. Test ENV_FILE override
	tmpDir := t.TempDir()
	customEnv := filepath.Join(tmpDir, "custom.env")
	if err := os.WriteFile(customEnv, []byte("FOO=BAR\n"), 0600); err != nil {
		t.Fatalf("failed to create custom env file: %v", err)
	}

	_ = os.Setenv("ENV_FILE", customEnv)
	defer os.Unsetenv("ENV_FILE")

	found, err := FindRootEnvFile()
	if err != nil {
		t.Fatalf("FindRootEnvFile failed with ENV_FILE set: %v", err)
	}

	absCustom, _ := filepath.Abs(customEnv)
	if found != absCustom {
		t.Errorf("expected found path %q, got %q", absCustom, found)
	}
}

