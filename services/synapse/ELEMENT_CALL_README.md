# Element Call Integration for Matrix Synapse

This integration adds Element Call (MatrixRTC) support to the Matrix Synapse homeserver, enabling encrypted video calls with scalable SFU backend.

## Components Added

### 1. LiveKit SFU (`livekit-sfu`)
- **Image**: `livekit/livekit-server`
- **Purpose**: Selective Forwarding Unit for WebRTC media routing
- **Ports**:
  - 7880/tcp - WebSocket/HTTP signaling
  - 7881/tcp - WebRTC TCP fallback
  - 50100-50200/udp - WebRTC media streams
- **Config**: `/config/livekit-config.yaml`
- **Endpoint**: `https://matrix-rtc-sfu.emdecloud.de`

### 2. Element Call JWT Service (`element-call-jwt`)
- **Image**: `ghcr.io/element-hq/lk-jwt-service`
- **Purpose**: JWT authentication for LiveKit SFU access
- **Port**: 8080/tcp
- **Endpoint**: `https://matrix-rtc-jwt.emdecloud.de`

(### 3. Element Call Web App (`element-call-app`)
- **Image**: `ghcr.io/element-hq/element-call`
- **Purpose**: Standalone Element Call web interface
- **Port**: 80/tcp
- **Config**: `/config/element-call-config.json`
- **Endpoint**: `https://element-call.emdecloud.de`) TODO?

## Configuration Changes

### Synapse homeserver.yaml
- Added `msc4140_enabled: true` for delayed events support
- Existing rate limiting already configured for Element Call compatibility

### Matrix Well-Known Client
Updated `/.well-known/matrix/client` to advertise MatrixRTC backend:
```json
{
  "org.matrix.msc4143.rtc_foci": [
    {
      "type": "livekit",
      "livekit_service_url": "https://matrix-rtc-jwt.emdecloud.de"
    }
  ]
}
```

## Required Secrets

Add these secrets via the secret management system:

1. **LIVEKIT_KEY** - LiveKit API key (e.g., "devkey")
2. **LIVEKIT_SECRET** - LiveKit secret key (long random string)

Both services must use the same key/secret pair.

## MSCs Required

Element Call requires these Matrix Specification Changes:
- **MSC3266**: Room Summary API (federation knocking)
- **MSC4140**: Delayed Events (call signaling) ✅ Added
- **MSC4222**: Sync v2 state_after (room state tracking)

## Debugging
1. Join a room in Element Web
2. Start a voice/video call
3. Look at network tab in developer tools

## Testing

1. Join a room in Element X or Element Web
2. Start a voice/video call
3. Verify WebRTC connection through LiveKit SFU
4. Check logs for successful JWT authentication

## References

- [Element Call Self-Hosting Guide](https://github.com/element-hq/element-call/blob/livekit/docs/self-hosting.md)
- [Blog: Deploy Element Call with Docker Compose](https://willlewis.co.uk/blog/posts/deploy-element-call-backend-with-synapse-and-docker-compose/)
- [MSC4195: MatrixRTC using LiveKit](https://github.com/hughns/matrix-spec-proposals/blob/hughns/matrixrtc-livekit/proposals/4195-matrixrtc-livekit.md)
