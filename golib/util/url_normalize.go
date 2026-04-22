package util

import (
	"fmt"
	"net/url"
	"strings"
)

// NormalizeHTTPBase normalizes user-provided base URLs for the signaling/discovery servers.
//
// It:
// - trims spaces
// - adds an http:// scheme if missing
// - removes any trailing slash
// - removes query/fragment
// - rejects unresolved placeholders like "[IP]"
//
// Returned value is safe to use as a base for appending paths.
func NormalizeHTTPBase(raw string) (string, error) {
	s := strings.TrimSpace(raw)
	if s == "" {
		return "", fmt.Errorf("empty URL")
	}
	if strings.Contains(s, "[IP]") {
		return "", fmt.Errorf("unresolved placeholder in URL: %q", raw)
	}

	// Allow schemeless host:port input.
	if strings.HasPrefix(s, "//") {
		s = "http:" + s
	}
	if !strings.Contains(s, "://") {
		s = "http://" + s
	}

	u, err := url.Parse(s)
	if err != nil {
		return "", fmt.Errorf("invalid URL %q: %w", raw, err)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return "", fmt.Errorf("unsupported scheme %q", u.Scheme)
	}
	if u.Host == "" {
		return "", fmt.Errorf("invalid URL %q: missing host", raw)
	}

	u.RawQuery = ""
	u.Fragment = ""
	u.Path = strings.TrimRight(u.Path, "/")

	out := u.String()
	out = strings.TrimRight(out, "/")
	return out, nil
}

// NormalizeICEServer ensures the ICE server string is in pion/webrtc format.
// Accepts:
// - host:port
// - stun:host:port
// - turn:host:port
// - turns:host:port
func NormalizeICEServer(raw string) string {
	s := strings.TrimSpace(raw)
	if s == "" {
		return s
	}
	lower := strings.ToLower(s)
	if strings.HasPrefix(lower, "stun:") || strings.HasPrefix(lower, "turn:") || strings.HasPrefix(lower, "turns:") {
		return s
	}
	return "stun:" + s
}
