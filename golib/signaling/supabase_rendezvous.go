package signaling

import (
  "bytes"
  "encoding/json"
  "errors"
  "fmt"
  "io"
  "math/rand"
  "net/http"
  "net/url"
  "strings"
  "time"

  "natproxy/golib/util"
)

// Supabase REST (PostgREST) rendezvous backend.
//
// This replaces the need to run a custom public signaling/discovery server.
// The mobile apps talk to Supabase directly using the anon key.

const supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ6dHdhZHBxb29oYWJiZW1xdXRwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2OTYwNzUsImV4cCI6MjA5MjI3MjA3NX0.bu2wirl4VYE29YxagljDCabnO8GxjU_JYTQwlEaIse4"

func isSupabaseURL(signalingURL string) bool {
  return strings.HasPrefix(signalingURL, "supabase://")
}

func supabaseProjectRef(signalingURL string) (string, error) {
  u, err := url.Parse(signalingURL)
  if err != nil {
    return "", err
  }
  ref := strings.TrimSpace(u.Host)
  if ref == "" {
    // allow supabase:///ref
    ref = strings.Trim(strings.TrimPrefix(u.Path, "/"), " ")
  }
  if ref == "" {
    return "", fmt.Errorf("supabase url missing project ref")
  }
  return ref, nil
}

func supabaseRestBase(signalingURL string) (string, error) {
  ref, err := supabaseProjectRef(signalingURL)
  if err != nil {
    return "", err
  }
  return fmt.Sprintf("https://%s.supabase.co/rest/v1", ref), nil
}

func newSupabaseRequest(method, fullURL string, body []byte) (*http.Request, error) {
  var r io.Reader
  if body != nil {
    r = bytes.NewReader(body)
  }
  req, err := http.NewRequest(method, fullURL, r)
  if err != nil {
    return nil, err
  }
  req.Header.Set("apikey", supabaseAnonKey)
  req.Header.Set("Authorization", "Bearer "+supabaseAnonKey)
  req.Header.Set("Content-Type", "application/json")
  req.Header.Set("Accept", "application/json")
  return req, nil
}

func randomListingID() string {
  const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  b := make([]byte, 12)
  for i := range b {
    b[i] = letters[rand.Intn(len(letters))]
  }
  return string(b)
}

// ---- Sessions (offer/answer) ----

type supaSessionRow struct {
  SessionID string           `json:"session_id"`
  Offer     *json.RawMessage `json:"offer,omitempty"`
  Answer    *json.RawMessage `json:"answer,omitempty"`
}

func supaUpsertSession(signalingURL, sessionID string, field string, payload []byte) error {
  base, err := supabaseRestBase(signalingURL)
  if err != nil {
    return err
  }

  raw := json.RawMessage(payload)
  row := map[string]any{"session_id": sessionID}
  row[field] = &raw

  body, _ := json.Marshal(row)

  // Upsert via POST + on_conflict.
  full := fmt.Sprintf("%s/rendezvous_sessions?on_conflict=session_id", base)
  req, err := newSupabaseRequest(http.MethodPost, full, body)
  if err != nil {
    return err
  }
  req.Header.Set("Prefer", "resolution=merge-duplicates,return=minimal")

  resp, err := httpClient.Do(req)
  if err != nil {
    return err
  }
  defer resp.Body.Close()

  if resp.StatusCode != 201 && resp.StatusCode != 200 {
    b, _ := io.ReadAll(resp.Body)
    return fmt.Errorf("supabase upsert session: status %d: %s", resp.StatusCode, string(b))
  }
  return nil
}

func supaGetSessionField(signalingURL, sessionID string, field string) ([]byte, error) {
  base, err := supabaseRestBase(signalingURL)
  if err != nil {
    return nil, err
  }

  full := fmt.Sprintf("%s/rendezvous_sessions?select=%s&session_id=eq.%s&limit=1", base, field, url.QueryEscape(sessionID))
  req, err := newSupabaseRequest(http.MethodGet, full, nil)
  if err != nil {
    return nil, err
  }

  resp, err := httpClient.Do(req)
  if err != nil {
    return nil, err
  }
  defer resp.Body.Close()

  if resp.StatusCode != 200 {
    b, _ := io.ReadAll(resp.Body)
    return nil, fmt.Errorf("supabase get session: status %d: %s", resp.StatusCode, string(b))
  }

  var rows []map[string]json.RawMessage
  b, err := io.ReadAll(resp.Body)
  if err != nil {
    return nil, err
  }
  if err := json.Unmarshal(b, &rows); err != nil {
    return nil, err
  }
  if len(rows) == 0 {
    return nil, nil
  }
  v, ok := rows[0][field]
  if !ok || len(v) == 0 || string(v) == "null" {
    return nil, nil
  }
  return v, nil
}

func supaWaitSessionField(signalingURL, sessionID, field string, timeout time.Duration) ([]byte, error) {
  backoff := util.NewBackoff(500*time.Millisecond, 5*time.Second, 0.5)
  deadline := time.Now().Add(timeout)
  for time.Now().Before(deadline) {
    v, err := supaGetSessionField(signalingURL, sessionID, field)
    if err != nil {
      time.Sleep(backoff.Next())
      continue
    }
    if v != nil {
      return v, nil
    }
    time.Sleep(backoff.Next())
  }
  return nil, errors.New("timeout")
}

// ---- Listings (discovery) ----

func supaRegisterListing(signalingURL, name, room, code, method, transport, protocol string, natInfo ...string) (string, error) {
  base, err := supabaseRestBase(signalingURL)
  if err != nil {
    return "", err
  }
  id := randomListingID()
  row := map[string]any{
    "id": id,
    "name": name,
    "room": room,
    "code": code,
    "method": method,
    "transport": transport,
    "protocol": protocol,
  }
  if len(natInfo) >= 1 && natInfo[0] != "" {
    row["nat_mapping"] = natInfo[0]
  }
  if len(natInfo) >= 2 && natInfo[1] != "" {
    row["nat_filtering"] = natInfo[1]
  }

  body, _ := json.Marshal(row)
  full := fmt.Sprintf("%s/rendezvous_listings?on_conflict=id", base)
  req, err := newSupabaseRequest(http.MethodPost, full, body)
  if err != nil {
    return "", err
  }
  req.Header.Set("Prefer", "resolution=merge-duplicates,return=minimal")

  resp, err := httpClient.Do(req)
  if err != nil {
    return "", err
  }
  defer resp.Body.Close()

  if resp.StatusCode != 201 && resp.StatusCode != 200 {
    b, _ := io.ReadAll(resp.Body)
    return "", fmt.Errorf("supabase register listing: status %d: %s", resp.StatusCode, string(b))
  }
  return id, nil
}

func supaDeleteListing(signalingURL, id string) error {
  base, err := supabaseRestBase(signalingURL)
  if err != nil {
    return err
  }
  full := fmt.Sprintf("%s/rendezvous_listings?id=eq.%s", base, url.QueryEscape(id))
  req, err := newSupabaseRequest(http.MethodDelete, full, nil)
  if err != nil {
    return err
  }
  resp, err := httpClient.Do(req)
  if err != nil {
    return err
  }
  defer resp.Body.Close()
  if resp.StatusCode != 204 && resp.StatusCode != 200 {
    b, _ := io.ReadAll(resp.Body)
    return fmt.Errorf("supabase delete listing: status %d: %s", resp.StatusCode, string(b))
  }
  return nil
}

func supaHeartbeatListing(signalingURL, id string) error {
  base, err := supabaseRestBase(signalingURL)
  if err != nil {
    return err
  }
  // Trigger updated_at by forcing an update (no-op field assignment).
  body := []byte(`{"id":"` + id + `"}`)
  full := fmt.Sprintf("%s/rendezvous_listings?id=eq.%s", base, url.QueryEscape(id))
  req, err := newSupabaseRequest(http.MethodPatch, full, body)
  if err != nil {
    return err
  }
  req.Header.Set("Prefer", "return=minimal")
  resp, err := httpClient.Do(req)
  if err != nil {
    return err
  }
  defer resp.Body.Close()
  if resp.StatusCode == 404 {
    return ErrListingExpired
  }
  if resp.StatusCode != 204 && resp.StatusCode != 200 {
    b, _ := io.ReadAll(resp.Body)
    return fmt.Errorf("supabase heartbeat listing: status %d: %s", resp.StatusCode, string(b))
  }
  return nil
}

func supaListListings(signalingURL, room string) (string, error) {
  base, err := supabaseRestBase(signalingURL)
  if err != nil {
    return "", err
  }
  sel := "id,name,room,code,method,transport,protocol"
  full := fmt.Sprintf("%s/rendezvous_listings?select=%s&order=updated_at.desc", base, sel)
  if room != "" {
    full += "&room=eq." + url.QueryEscape(room)
  }
  req, err := newSupabaseRequest(http.MethodGet, full, nil)
  if err != nil {
    return "", err
  }
  resp, err := httpClient.Do(req)
  if err != nil {
    return "", err
  }
  defer resp.Body.Close()
  b, err := io.ReadAll(resp.Body)
  if err != nil {
    return "", err
  }
  if resp.StatusCode != 200 {
    return "", fmt.Errorf("supabase list listings: status %d: %s", resp.StatusCode, string(b))
  }
  return string(b), nil
}
