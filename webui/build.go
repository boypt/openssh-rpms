package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
)

var buildMutex sync.Mutex

type BuildRequest struct {
	TargetEL       string `json:"target_el"`
	OpenSSLMode    string `json:"openssl_mode"`
	OpenSSHVersion string `json:"openssh_version"`
	OpenSSLVersion string `json:"openssl_version"`
}

type BuildResponse struct {
	Success bool     `json:"success"`
	Log     string   `json:"log"`
	RPMs    []string `json:"rpms"`
}

func repoRoot() string {
	root, err := filepath.Abs("..")
	if err != nil {
		return ".."
	}
	return root
}

func listRPMs() []string {
	outputDir := filepath.Join(repoRoot(), "output")
	entries, err := os.ReadDir(outputDir)
	if err != nil {
		return []string{}
	}

	var rpms []string
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".rpm") {
			rpms = append(rpms, entry.Name())
		}
	}

	sort.Strings(rpms)
	return rpms
}

func buildHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if !buildMutex.TryLock() {
		http.Error(w, "A build is already running", http.StatusConflict)
		return
	}
	defer buildMutex.Unlock()

	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	var req BuildRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	if !regexp.MustCompile(`^[0-9]+(\.[0-9]+)*p[0-9]+$`).MatchString(req.OpenSSHVersion) {
		http.Error(w, "Invalid OpenSSH version", http.StatusBadRequest)
		return
	}

	if !regexp.MustCompile(`^[0-9]+(\.[0-9]+)*[a-z]?$`).MatchString(req.OpenSSLVersion) {
		http.Error(w, "Invalid OpenSSL version", http.StatusBadRequest)
		return
	}

	specMap := map[string]string{
		"el5": "el5",
		"el6": "el6",
		"el7": "el7",
		"el8": "el7",
		"el9": "el7",
	}

	specDir, ok := specMap[req.TargetEL]
	if !ok {
		http.Error(w, "Invalid target EL", http.StatusBadRequest)
		return
	}

	if req.OpenSSLMode != "0" && req.OpenSSLMode != "1" && req.OpenSSLMode != "2" {
		http.Error(w, "Invalid OpenSSL mode", http.StatusBadRequest)
		return
	}

	root := repoRoot()

	localEnv := fmt.Sprintf(
		"OPENSSHSRC=openssh-%s.tar.gz\nOPENSSLSRC=openssl-%s.tar.gz\n",
		req.OpenSSHVersion,
		req.OpenSSLVersion,
	)

	if err := os.WriteFile(filepath.Join(root, "version-local.env"), []byte(localEnv), 0644); err != nil {
		http.Error(w, "Cannot save version configuration", http.StatusInternalServerError)
		return
	}

	pull := exec.Command("./pullsrc.sh")
	pull.Dir = root
	pullOutput, pullErr := pull.CombinedOutput()

	if pullErr != nil {
		writeBuildError(w, "Source download failed:\n"+string(pullOutput))
		return
	}

	cmd := exec.Command("./compile.sh", specDir)
	cmd.Dir = root

	env := make([]string, 0, len(os.Environ())+1)
	for _, item := range os.Environ() {
		if !strings.HasPrefix(item, "WITH_OPENSSL=") {
			env = append(env, item)
		}
	}
	env = append(env, "WITH_OPENSSL="+req.OpenSSLMode)
	cmd.Env = env

	output, err := cmd.CombinedOutput()

	result := BuildResponse{
		Success: err == nil,
		Log:     string(pullOutput) + "\n" + string(output),
		RPMs:    []string{},
	}

	if err == nil {
		result.RPMs = listRPMs()
	}

	w.Header().Set("Content-Type", "application/json")
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
	}
	_ = json.NewEncoder(w).Encode(result)
}

func writeBuildError(w http.ResponseWriter, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusInternalServerError)
	_ = json.NewEncoder(w).Encode(BuildResponse{
		Success: false,
		Log:     message,
		RPMs:    []string{},
	})
}

func downloadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	name := filepath.Base(r.URL.Query().Get("file"))
	if name == "." || name == "" || !strings.HasSuffix(name, ".rpm") {
		http.Error(w, "Invalid RPM filename", http.StatusBadRequest)
		return
	}

	path := filepath.Join(repoRoot(), "output", name)
	info, err := os.Stat(path)
	if err != nil || !info.Mode().IsRegular() {
		http.NotFound(w, r)
		return
	}

	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", name))
	http.ServeFile(w, r, path)
}
