package main

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

type VersionInfo struct {
	OpenSSHVersion string `json:"openssh_version"`
	OpenSSLVersion string `json:"openssl_version"`
}

func readEnvFile(path string, values map[string]string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)

		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, found := strings.Cut(line, "=")
		if !found {
			continue
		}

		key = strings.TrimSpace(key)
		value = strings.TrimSpace(value)

		// Ignore shell expressions such as ${OPENSSLSRC%%.tar.gz}.
		if strings.Contains(value, "${") {
			continue
		}

		values[key] = strings.Trim(value, "\"'")
	}

	return nil
}

func versionFromSource(source, prefix string) string {
	source = filepath.Base(source)
	source = strings.TrimSuffix(source, ".tar.gz")
	source = strings.TrimPrefix(source, prefix)
	return source
}

func versionHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	root := ".."
	if _, err := os.Stat(filepath.Join(root, "version.env")); err != nil {
		root = "."
	}

	values := make(map[string]string)

	if err := readEnvFile(filepath.Join(root, "version.env"), values); err != nil {
		http.Error(w, "Cannot read version.env", http.StatusInternalServerError)
		return
	}

	localEnv := filepath.Join(root, "version-local.env")
	if _, err := os.Stat(localEnv); err == nil {
		if err := readEnvFile(localEnv, values); err != nil {
			http.Error(w, "Cannot read version-local.env", http.StatusInternalServerError)
			return
		}
	}

	result := VersionInfo{
		OpenSSHVersion: versionFromSource(values["OPENSSHSRC"], "openssh-"),
		OpenSSLVersion: versionFromSource(values["OPENSSLSRC"], "openssl-"),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}
