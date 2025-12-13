# Navidrome Music Server

Navidrome is a modern music server and streamer compatible with Subsonic/Airsonic clients.

## Features

- Web-based music player
- Subsonic API compatibility
- Smart playlists
- Multi-user support with user management
- Last.fm scrobbling
- Transcoding support

## Configuration

### Volume Mounts

- `/data/services/navidrome/data` - Navidrome data directory (database, cache, etc.)
- `/data/nas/files/Musik` - Music library (read-only)

### Authentication

This service is protected by Authentik forward authentication with dual authentication modes:

1. **Web Interface**: Standard web-based authentication via Authentik
2. **Subsonic API**: Basic authentication for mobile apps and desktop clients

#### Setting up Authentik Integration

1. Log into Authentik admin panel (`https://auth.emdecloud.de`)
2. Create a new Provider:
   - Type: **Proxy Provider**
   - Name: `Navidrome`
   - Authorization flow: Choose your preferred flow
   - External host: `https://navidrome.emdecloud.de`
   - Mode: **Forward auth (single application)**
   - Advanced settings: Enable **Basic Auth** support for Subsonic clients
3. Create a new Application:
   - Name: `Navidrome`
   - Slug: `navidrome`
   - Provider: Select the provider created above
4. The forward auth middleware is already configured in the Traefik labels with two routes:
   - Default route: Web-based authentication for browser access
   - Subsonic route (`/rest/*`): Basic auth for API clients (excluding NavidromeUI web app)

### Environment Variables

Optional environment variables can be set in `/secrets/navidrome/.env`:

- `ND_ENCRYPTIONKEY` - Encryption key for data at rest

### Default Settings

- Scan schedule: Every 1 hour
- Log level: info
- Session timeout: 24 hours
- Port: 4533
- Reverse proxy authentication: Enabled (uses `Remote-User` header from Authentik)
- Internal authentication: Bypassed (authentication handled entirely by Authentik)

## Access

- URL: `https://navidrome.emdecloud.de`
- Local URL: `http://navidrome.mahler.local`

## First Time Setup

After deployment:
1. Ensure users exist in Authentik with matching usernames
2. Access the web interface (you'll be authenticated via Authentik)
3. First user to login will be created as admin automatically
4. Navidrome will automatically scan the music directory
5. Additional users are auto-created on first login based on Authentik username

## Subsonic API

Mobile apps and desktop clients can connect using:
- Server URL: `https://navidrome.emdecloud.de`
- Username: Your Authentik username
- Password: Your Authentik password

**Important**: 
- The Subsonic API endpoint (`/rest/*`) uses HTTP Basic Auth via Authentik
- Authentication is handled at the Traefik level, not by Navidrome
- Navidrome automatically creates/logs in users based on the `Remote-User` header
- No password management needed within Navidrome itself

## Notes

- Music directory is mounted read-only for safety
- The service runs as user 1000:1000
- Automatic library scanning occurs every hour
- **All authentication is handled by Authentik** - Navidrome trusts the `Remote-User` header
- User editing is disabled in Navidrome (managed via Authentik)
- All IPs are trusted as reverse proxy (authentication is at Traefik level)
- The NavidromeUI web app uses standard web auth, not basic auth
- Users are automatically created in Navidrome on first login with their Authentik username
- First user to login becomes admin automatically

## User Management

Since Navidrome uses reverse proxy authentication:

1. **Add users in Authentik** - Create users/groups in Authentik admin panel
2. **Auto-creation** - Users are automatically created in Navidrome when they first access the service
3. **Permissions** - Manage permissions within Navidrome UI (playlist access, admin rights, etc.)
4. **No passwords** - Users never need to set/remember a Navidrome password
5. **Username matching** - Ensure Authentik usernames match desired Navidrome usernames
