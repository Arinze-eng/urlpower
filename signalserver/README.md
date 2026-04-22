# Signaling + Discovery Server (with UDP relay)

Your mobile app’s P2P/WebRTC transport expects a **public signaling server** that provides:
- exchanging SDP offers/answers
- discovery listings (so clients can “see” available hosts)
- optional UDP relay fallback (for restrictive NATs)

This folder provides a **standalone Go server** that implements exactly the endpoints used by the app.

## 1) Build

On a Linux VPS with Go installed:

```bash
cd signalserver
go build -o signalserver ./cmd/signalserver
```

## 2) Run (recommended ports)

Open these ports on your VPS firewall/security group:
- **TCP 5601** (HTTP signaling + discovery)
- **UDP 3478** (UDP relay fallback)

Then run:

```bash
./signalserver -http :5601 -relay :3478
```

Health check:

```bash
curl http://YOUR_VPS_IP:5601/health
```

## 3) Configure the app

In **Server settings** and **Client settings**:
- **Signaling URL**: `http://YOUR_VPS_IP:5601`
- **Discovery URL**: `http://YOUR_VPS_IP:5601` (or a separate discovery host if you want)

If you enable “Use Relay” in server settings, the app will automatically derive the relay address as:
- `YOUR_VPS_IP:3478`

## Notes

- **Discovery listings are ephemeral** and require heartbeat; the app already sends heartbeat.
- `localhost` only works when the app and server are on the same machine. For internet use, always use your VPS public IP/domain.
