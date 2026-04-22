package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// signalserver implements the HTTP signaling + discovery API expected by the mobile app
// (golib/signaling/signaling.go), plus the optional UDP relay fallback used by the
// WebRTC transport (golib/webrtc/peer.go).
//
// HTTP endpoints:
// - POST/GET /session/{id}/offer
// - POST/GET /session/{id}/answer
// - GET      /session/{id}/offer/stream  (SSE)
// - GET      /session/{id}/answer/stream (SSE)
// - POST     /discovery/register
// - DELETE   /discovery/{listingID}
// - POST     /discovery/{listingID}/heartbeat
// - GET      /discovery/servers
// - GET      /discovery/stream (SSE)
//
// UDP relay:
// - UDP :3478 by default
// - registration packet format is defined in golib/webrtc/peer.go (registerRelay)

// ====== Session store (offer/answer) ======

type sessionEntry struct {
	Offer     json.RawMessage
	Answer    json.RawMessage
	UpdatedAt time.Time
}

type sessionHub struct {
	mu       sync.RWMutex
	sessions map[string]*sessionEntry
	watchO   map[string]map[chan struct{}]struct{}
	watchA   map[string]map[chan struct{}]struct{}
}

func newSessionHub() *sessionHub {
	return &sessionHub{
		sessions: make(map[string]*sessionEntry),
		watchO:   make(map[string]map[chan struct{}]struct{}),
		watchA:   make(map[string]map[chan struct{}]struct{}),
	}
}

func (h *sessionHub) get(sessionID string) (*sessionEntry, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	e, ok := h.sessions[sessionID]
	if !ok {
		return nil, false
	}
	cpy := *e
	cpy.Offer = append(json.RawMessage(nil), e.Offer...)
	cpy.Answer = append(json.RawMessage(nil), e.Answer...)
	return &cpy, true
}

func (h *sessionHub) setOffer(sessionID string, body []byte) {
	h.mu.Lock()
	e := h.sessions[sessionID]
	if e == nil {
		e = &sessionEntry{}
		h.sessions[sessionID] = e
	}
	e.Offer = append(json.RawMessage(nil), body...)
	e.UpdatedAt = time.Now()
	watchers := h.watchO[sessionID]
	h.mu.Unlock()
	for ch := range watchers {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

func (h *sessionHub) setAnswer(sessionID string, body []byte) {
	h.mu.Lock()
	e := h.sessions[sessionID]
	if e == nil {
		e = &sessionEntry{}
		h.sessions[sessionID] = e
	}
	e.Answer = append(json.RawMessage(nil), body...)
	e.UpdatedAt = time.Now()
	watchers := h.watchA[sessionID]
	h.mu.Unlock()
	for ch := range watchers {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

func (h *sessionHub) watchOffer(sessionID string) (<-chan struct{}, func()) {
	ch := make(chan struct{}, 1)
	h.mu.Lock()
	m := h.watchO[sessionID]
	if m == nil {
		m = make(map[chan struct{}]struct{})
		h.watchO[sessionID] = m
	}
	m[ch] = struct{}{}
	h.mu.Unlock()
	stop := func() {
		h.mu.Lock()
		if mm := h.watchO[sessionID]; mm != nil {
			delete(mm, ch)
			if len(mm) == 0 {
				delete(h.watchO, sessionID)
			}
		}
		h.mu.Unlock()
		close(ch)
	}
	return ch, stop
}

func (h *sessionHub) watchAnswer(sessionID string) (<-chan struct{}, func()) {
	ch := make(chan struct{}, 1)
	h.mu.Lock()
	m := h.watchA[sessionID]
	if m == nil {
		m = make(map[chan struct{}]struct{})
		h.watchA[sessionID] = m
	}
	m[ch] = struct{}{}
	h.mu.Unlock()
	stop := func() {
		h.mu.Lock()
		if mm := h.watchA[sessionID]; mm != nil {
			delete(mm, ch)
			if len(mm) == 0 {
				delete(h.watchA, sessionID)
			}
		}
		h.mu.Unlock()
		close(ch)
	}
	return ch, stop
}

func (h *sessionHub) gcLoop(ctx context.Context, ttl time.Duration) {
	if ttl <= 0 {
		return
	}
	ticker := time.NewTicker(ttl / 2)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			cutoff := time.Now().Add(-ttl)
			h.mu.Lock()
			for id, e := range h.sessions {
				if e.UpdatedAt.Before(cutoff) {
					delete(h.sessions, id)
					delete(h.watchO, id)
					delete(h.watchA, id)
				}
			}
			h.mu.Unlock()
		}
	}
}

// ====== Discovery store ======

type listing struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Room         string    `json:"room"`
	Code         string    `json:"code"`
	Method       string    `json:"method"`
	Transport    string    `json:"transport"`
	Protocol     string    `json:"protocol"`
	NatMapping   string    `json:"nat_mapping,omitempty"`
	NatFiltering string    `json:"nat_filtering,omitempty"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type discoveryHub struct {
	mu       sync.RWMutex
	listings map[string]*listing
	watchers map[chan struct{}]struct{}
}

func newDiscoveryHub() *discoveryHub {
	return &discoveryHub{listings: make(map[string]*listing), watchers: make(map[chan struct{}]struct{})}
}

func (d *discoveryHub) register(l *listing) string {
	d.mu.Lock()
	defer d.mu.Unlock()
	if l.ID == "" {
		l.ID = randomID(12)
	}
	l.UpdatedAt = time.Now()
	d.listings[l.ID] = l
	return l.ID
}

func (d *discoveryHub) heartbeat(id string) bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	l := d.listings[id]
	if l == nil {
		return false
	}
	l.UpdatedAt = time.Now()
	return true
}

func (d *discoveryHub) remove(id string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	delete(d.listings, id)
}

func (d *discoveryHub) list(room string) []*listing {
	d.mu.RLock()
	defer d.mu.RUnlock()
	out := make([]*listing, 0, len(d.listings))
	for _, l := range d.listings {
		if room != "" && l.Room != room {
			continue
		}
		cpy := *l
		out = append(out, &cpy)
	}
	return out
}

func (d *discoveryHub) watch() (<-chan struct{}, func()) {
	ch := make(chan struct{}, 1)
	d.mu.Lock()
	d.watchers[ch] = struct{}{}
	d.mu.Unlock()
	stop := func() {
		d.mu.Lock()
		delete(d.watchers, ch)
		d.mu.Unlock()
		close(ch)
	}
	return ch, stop
}

func (d *discoveryHub) notifyAll() {
	d.mu.RLock()
	chs := make([]chan struct{}, 0, len(d.watchers))
	for ch := range d.watchers {
		chs = append(chs, ch)
	}
	d.mu.RUnlock()
	for _, ch := range chs {
		select {
		case ch <- struct{}{}:
		default:
		}
	}
}

func (d *discoveryHub) gcLoop(ctx context.Context, ttl time.Duration) {
	if ttl <= 0 {
		return
	}
	ticker := time.NewTicker(ttl / 2)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			cutoff := time.Now().Add(-ttl)
			changed := false
			d.mu.Lock()
			for id, l := range d.listings {
				if l.UpdatedAt.Before(cutoff) {
					delete(d.listings, id)
					changed = true
				}
			}
			d.mu.Unlock()
			if changed {
				d.notifyAll()
			}
		}
	}
}

// ====== UDP relay ======

type relayPeer struct {
	addr      *net.UDPAddr
	updatedAt time.Time
}

type relaySession struct {
	server *relayPeer
	client *relayPeer
}

type udpRelay struct {
	mu       sync.RWMutex
	sessions map[[16]byte]*relaySession
	recv     atomic.Uint64
	sent     atomic.Uint64
}

func newUDPRelay() *udpRelay {
	return &udpRelay{sessions: make(map[[16]byte]*relaySession)}
}

func (r *udpRelay) handlePacket(pkt []byte, from *net.UDPAddr, conn *net.UDPConn) {
	r.recv.Add(1)

	// Registration packet: [magic(4)][key16][role(1)]
	if len(pkt) == 21 && pkt[0] == 0xDE && pkt[1] == 0xAD && pkt[2] == 0xBE && pkt[3] == 0xEF {
		var key [16]byte
		copy(key[:], pkt[4:20])
		role := pkt[20]

		r.mu.Lock()
		s := r.sessions[key]
		if s == nil {
			s = &relaySession{}
			r.sessions[key] = s
		}
		peer := &relayPeer{addr: from, updatedAt: time.Now()}
		if role == 0x01 {
			s.client = peer
		} else {
			s.server = peer
		}
		r.mu.Unlock()
		return
	}

	// Data packet: forward to opposite peer.
	r.mu.RLock()
	var target *net.UDPAddr
	for _, s := range r.sessions {
		if s.server != nil && addrEqual(s.server.addr, from) {
			if s.client != nil {
				target = s.client.addr
			}
			break
		}
		if s.client != nil && addrEqual(s.client.addr, from) {
			if s.server != nil {
				target = s.server.addr
			}
			break
		}
	}
	r.mu.RUnlock()
	if target == nil {
		return
	}

	_, _ = conn.WriteToUDP(pkt, target)
	r.sent.Add(1)
}

func addrEqual(a, b *net.UDPAddr) bool {
	if a == nil || b == nil {
		return false
	}
	return a.IP.Equal(b.IP) && a.Port == b.Port
}

func (r *udpRelay) gcLoop(ctx context.Context, ttl time.Duration) {
	if ttl <= 0 {
		return
	}
	ticker := time.NewTicker(ttl / 2)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			cutoff := time.Now().Add(-ttl)
			r.mu.Lock()
			for k, s := range r.sessions {
				stale := true
				if s.server != nil && s.server.updatedAt.After(cutoff) {
					stale = false
				}
				if s.client != nil && s.client.updatedAt.After(cutoff) {
					stale = false
				}
				if stale {
					delete(r.sessions, k)
				}
			}
			r.mu.Unlock()
		}
	}
}

// ====== HTTP server ======

type apiServer struct {
	sessions  *sessionHub
	discovery *discoveryHub
}

func (s *apiServer) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/session/", s.handleSession)
	mux.HandleFunc("/discovery/register", s.handleDiscoveryRegister)
	mux.HandleFunc("/discovery/servers", s.handleDiscoveryServers)
	mux.HandleFunc("/discovery/stream", s.handleDiscoveryStream)
	mux.HandleFunc("/discovery/", s.handleDiscoveryItem)
	return logRequests(mux)
}

func (s *apiServer) handleSession(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) < 3 || parts[0] != "session" {
		http.NotFound(w, r)
		return
	}
	sessionID := parts[1]
	kind := parts[2] // offer|answer
	isStream := len(parts) >= 4 && parts[3] == "stream"

	if isStream {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		s.handleSessionStream(w, r, sessionID, kind)
		return
	}

	switch r.Method {
	case http.MethodPost:
		body, err := readBodyLimit(r, 512*1024)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		var tmp any
		if err := json.Unmarshal(body, &tmp); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}
		if kind == "offer" {
			s.sessions.setOffer(sessionID, body)
			w.WriteHeader(http.StatusOK)
			return
		}
		if kind == "answer" {
			s.sessions.setAnswer(sessionID, body)
			w.WriteHeader(http.StatusOK)
			return
		}
		http.NotFound(w, r)
		return
	case http.MethodGet:
		e, ok := s.sessions.get(sessionID)
		if !ok {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		if kind == "offer" {
			if len(e.Offer) == 0 {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			_, _ = w.Write(e.Offer)
			return
		}
		if kind == "answer" {
			if len(e.Answer) == 0 {
				w.WriteHeader(http.StatusNotFound)
				return
			}
			_, _ = w.Write(e.Answer)
			return
		}
		http.NotFound(w, r)
		return
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *apiServer) handleSessionStream(w http.ResponseWriter, r *http.Request, sessionID, kind string) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "stream unsupported", http.StatusInternalServerError)
		return
	}

	ctx := r.Context()
	var notify <-chan struct{}
	var stop func()
	if kind == "offer" {
		notify, stop = s.sessions.watchOffer(sessionID)
	} else if kind == "answer" {
		notify, stop = s.sessions.watchAnswer(sessionID)
	} else {
		http.NotFound(w, r)
		return
	}
	defer stop()

	// send current if present
	s.sendSessionSSE(w, sessionID, kind)
	flusher.Flush()

	ka := time.NewTicker(15 * time.Second)
	defer ka.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ka.C:
			_, _ = w.Write([]byte(":keepalive\n\n"))
			flusher.Flush()
		case <-notify:
			s.sendSessionSSE(w, sessionID, kind)
			flusher.Flush()
		}
	}
}

func (s *apiServer) sendSessionSSE(w http.ResponseWriter, sessionID, kind string) {
	e, ok := s.sessions.get(sessionID)
	if !ok {
		return
	}
	var body json.RawMessage
	if kind == "offer" {
		body = e.Offer
	} else {
		body = e.Answer
	}
	if len(body) == 0 {
		return
	}
	_, _ = w.Write([]byte("data: "))
	_, _ = w.Write(body)
	_, _ = w.Write([]byte("\n\n"))
}

func (s *apiServer) handleDiscoveryRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	body, err := readBodyLimit(r, 64*1024)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	var data map[string]string
	if err := json.Unmarshal(body, &data); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}

	name := strings.TrimSpace(data["name"])
	code := strings.TrimSpace(data["code"])
	if name == "" || code == "" {
		http.Error(w, "missing name/code", http.StatusBadRequest)
		return
	}

	l := &listing{
		Name:         name,
		Room:         strings.TrimSpace(data["room"]),
		Code:         code,
		Method:       strings.TrimSpace(data["method"]),
		Transport:    strings.TrimSpace(data["transport"]),
		Protocol:     strings.TrimSpace(data["protocol"]),
		NatMapping:   strings.TrimSpace(data["nat_mapping"]),
		NatFiltering: strings.TrimSpace(data["nat_filtering"]),
	}
	id := s.discovery.register(l)
	s.discovery.notifyAll()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_, _ = w.Write([]byte(fmt.Sprintf(`{"id":"%s"}`, id)))
}

func (s *apiServer) handleDiscoveryItem(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) < 2 || parts[0] != "discovery" {
		http.NotFound(w, r)
		return
	}
	id := parts[1]
	if len(parts) == 2 {
		if r.Method != http.MethodDelete {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		s.discovery.remove(id)
		s.discovery.notifyAll()
		w.WriteHeader(http.StatusOK)
		return
	}
	if len(parts) == 3 && parts[2] == "heartbeat" {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		if ok := s.discovery.heartbeat(id); !ok {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusOK)
		return
	}
	http.NotFound(w, r)
}

func (s *apiServer) handleDiscoveryServers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	room := r.URL.Query().Get("room")
	list := s.discovery.list(room)
	sortByUpdatedDesc(list)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(list)
}

func (s *apiServer) handleDiscoveryStream(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "stream unsupported", http.StatusInternalServerError)
		return
	}

	room := r.URL.Query().Get("room")
	ctx := r.Context()
	notify, stop := s.discovery.watch()
	defer stop()

	s.sendDiscoveryServersSSE(w, room)
	flusher.Flush()

	ka := time.NewTicker(15 * time.Second)
	defer ka.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ka.C:
			_, _ = w.Write([]byte(":keepalive\n\n"))
			flusher.Flush()
		case <-notify:
			s.sendDiscoveryServersSSE(w, room)
			flusher.Flush()
		}
	}
}

func (s *apiServer) sendDiscoveryServersSSE(w http.ResponseWriter, room string) {
	list := s.discovery.list(room)
	sortByUpdatedDesc(list)
	b, _ := json.Marshal(list)
	_, _ = w.Write([]byte("event: servers\n"))
	_, _ = w.Write([]byte("data: "))
	_, _ = w.Write(b)
	_, _ = w.Write([]byte("\n\n"))
}

// ====== helpers ======

func readBodyLimit(r *http.Request, limit int64) ([]byte, error) {
	defer r.Body.Close()
	b, err := io.ReadAll(io.LimitReader(r.Body, limit))
	if err != nil {
		return nil, err
	}
	if len(b) == 0 {
		return nil, errors.New("empty body")
	}
	return b, nil
}

func randomID(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}

func sortByUpdatedDesc(list []*listing) {
	for i := 0; i < len(list); i++ {
		for j := i + 1; j < len(list); j++ {
			if list[j].UpdatedAt.After(list[i].UpdatedAt) {
				list[i], list[j] = list[j], list[i]
			}
		}
	}
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start))
	})
}

func mustResolveUDP(addr string) *net.UDPAddr {
	ua, err := net.ResolveUDPAddr("udp4", addr)
	if err != nil {
		log.Fatalf("resolve udp addr %s: %v", addr, err)
	}
	return ua
}

func main() {
	var (
		httpAddr      = flag.String("http", ":5601", "HTTP listen address")
		relayAddr     = flag.String("relay", ":3478", "UDP relay listen address")
		sessionTTL    = flag.Duration("session-ttl", 10*time.Minute, "offer/answer TTL")
		discoveryTTL  = flag.Duration("discovery-ttl", 60*time.Second, "discovery listing TTL (must be > heartbeat interval)")
		relayTTL      = flag.Duration("relay-ttl", 30*time.Second, "UDP relay peer TTL")
	)
	flag.Parse()

	rand.Seed(time.Now().UnixNano())

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sessions := newSessionHub()
	discovery := newDiscoveryHub()
	relay := newUDPRelay()

	go sessions.gcLoop(ctx, *sessionTTL)
	go discovery.gcLoop(ctx, *discoveryTTL)
	go relay.gcLoop(ctx, *relayTTL)

	udpConn, err := net.ListenUDP("udp4", mustResolveUDP(*relayAddr))
	if err != nil {
		log.Fatalf("listen udp relay: %v", err)
	}
	defer udpConn.Close()
	go func() {
		buf := make([]byte, 4096)
		for {
			n, addr, err := udpConn.ReadFromUDP(buf)
			if err != nil {
				return
			}
			pkt := append([]byte(nil), buf[:n]...)
			relay.handlePacket(pkt, addr, udpConn)
		}
	}()

	api := &apiServer{sessions: sessions, discovery: discovery}
	httpSrv := &http.Server{Addr: *httpAddr, Handler: api.routes()}

	go func() {
		log.Printf("signalserver: HTTP %s, UDP relay %s", *httpAddr, *relayAddr)
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("http server: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)
	<-stop

	cancel()
	ctx2, cancel2 := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel2()
	_ = httpSrv.Shutdown(ctx2)
}
