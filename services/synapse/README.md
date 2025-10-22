# Matrix Synapse Service

This directory contains the NixOS configuration for the Matrix Synapse homeserver with admin interface.

## Architecture

The service consists of four containers:
- **synapse-app**: The main Matrix Synapse server
- **synapse-database**: PostgreSQL database for persistent storage
- **synapse-redis**: Redis for caching and replication
- **synapse-admin**: Web-based admin interface for managing the homeserver

## Configuration

### Main Configuration
- `config/homeserver.yaml.j2`: Main Synapse configuration file
  - Uses Jinja2 template syntax for environment variable substitution (e.g., `{{ POSTGRES_PASSWORD }}`)
  - The official Synapse Docker image processes these templates at startup
  - **Enhanced**: Now includes Authentik group-based admin role mapping
- `config/log.config`: Logging configuration  
- `config/synapse-admin-config.json`: Configuration for the Synapse Admin web interface

### Secrets
The following secrets need to be generated and encrypted using agenix in the `services/synapse/secrets/` directory:

1. **POSTGRES_PASSWORD.env.age**: PostgreSQL database password
2. **SYNAPSE_REGISTRATION_SHARED_SECRET.env.age**: For registering users via the API
3. **SYNAPSE_MACAROON_SECRET_KEY.env.age**: For generating access tokens
4. **SYNAPSE_FORM_SECRET.env.age**: For securing forms
5. **AUTHENTIK_CLIENT_ID.env.age**: Authentik OAuth2 client ID for SSO
6. **AUTHENTIK_CLIENT_SECRET.env.age**: Authentik OAuth2 client secret for SSO

## Traefik Integration

The service is configured with **enhanced security routing** following Synapse documentation best practices:

### Matrix Server Routes
- **Public Client API**: `https://matrix.<domain>` - Restricted to `/_matrix` and `/_synapse/client` paths only
- **Admin API**: `https://matrix.<domain>/_synapse/admin` - Accessible for administration (requires authentication)
- **Federation**: `https://matrix.<domain>:8448` - Full Matrix federation (port 8448)
- **Local Access**: `https://matrix.<host>.local` - Full access for local administration

### Synapse Admin Interface  
- **Public Access**: `https://synapse-admin.<domain>` - Web-based admin interface
- **Local Access**: `https://synapse-admin.<host>.local` - Direct local access

This configuration follows the [Synapse reverse proxy documentation](https://element-hq.github.io/synapse/latest/reverse_proxy.html) which recommends only exposing `/_matrix` and `/_synapse/client` endpoints publicly, while keeping `/_synapse/admin` accessible but secured.

## Authentik SSO Integration

The service is configured with **enhanced Authentik OIDC integration**:
- **Provider URL**: `https://auth.<domain>/application/o/matrix/`
- **Scopes**: openid, profile, email, **groups** (new)
- **User mapping**: Maps Authentik username, display name, and email
- **Admin Role Mapping**: Users in the `matrix-admin` Authentik group automatically receive Synapse admin privileges

### Setting Up Admin Users via Authentik
1. In Authentik, create a group named `matrix-admin`
2. Add users to this group who should have Matrix server admin privileges
3. Users will automatically receive admin access when they log in via SSO

## Synapse Admin Interface

The service includes [Synapse Admin](https://github.com/etkecc/synapse-admin), a feature-rich web interface for managing your Matrix homeserver:

### Features
- **User Management**: Create, modify, deactivate users and manage their settings
- **Room Management**: View, modify, and delete rooms; manage room members and settings
- **Media Management**: View and delete media files, manage storage
- **Federation**: Monitor and manage federation with other Matrix servers
- **Server Statistics**: View detailed server metrics and statistics
- **Registration Tokens**: Manage user registration
- **Reports**: Handle abuse reports and moderation

### Access
- **Web Interface**: Available at `https://synapse-admin.<domain>`
- **Authentication**: Uses your Synapse server credentials (supports SSO via Authentik)
- **Admin Requirements**: Only Matrix server administrators can access the interface

### Configuration
The admin interface is pre-configured to:
- Connect only to your homeserver (`restrictBaseUrl`)
- Include custom menu items for Matrix resources
- Protect system users from accidental modification

## Data Storage

The service stores data in the following locations:
- `/data/services/synapse/database`: PostgreSQL database
- `/data/services/synapse/redis`: Redis persistence
- `/data/services/synapse/app`: Synapse data including media store and signing keys

## TODOs

### Required Setup Steps

- [x] **Generate and encrypt all required secrets** (see Secrets section above)
- [x] **Create data directories**:
  ```bash
  sudo mkdir -p /data/services/synapse/{db,redis,data/media_store,data/keys}
  sudo chown -R 991:991 /data/services/synapse/data  # Synapse runs as UID 991
  ```

- [x] **Configure database connection**: Ensure the database password is properly encrypted and available

- [x] **Generate signing keys**: On first run, Synapse will auto-generate signing keys in `/data/services/synapse/app/keys/`

### DNS Configuration

- [x] **Set up DNS entries** for federation to work properly:
  - `matrix.<host>.local` → Internal IP
  - `synapse.<host>.local` → Internal IP
  - For external federation, you'll need public DNS entries and proper port forwarding

- [ ] **Configure SRV records** (if using federation):
  ```
  _matrix._tcp.<host>.local. 3600 IN SRV 10 0 8448 synapse.<host>.local.
  ```

### Client Registration

- [ ] **Configure registration settings** in `config/homeserver.yaml`:
  - Set `enable_registration: true` if you want open registration
  - Or use the registration shared secret to register users manually

- [ ] **Register the first admin user**:
  ```bash
  docker exec -it synapse-app register_new_matrix_user -c /data/homeserver.yaml -u admin -p password -a http://localhost:8008
  ```

### Optional Enhancements

- [x] **Configure SMTP** for email notifications (see homeserver.yaml)
- [ ] **Set up TURN server** for VoIP functionality
- [ ] **Configure media retention policies** to manage storage
- [x] **Enable metrics** for monitoring with Prometheus
- [ ] **Configure room directory** and federation settings
- [ ] **Set up rate limiting** according to your needs
- [ ] **Configure CORS** if needed for web clients

### Security Configuration

- [ ] **Review and adjust rate limiting** settings in homeserver.yaml
- [ ] **Configure allowed federation domains** (whitelist/blacklist)
- [ ] **Set up proper firewall rules** for federation (port 8448)
- [ ] **Review security settings** in the Synapse documentation
- [ ] **Set up regular backups** of the database and media store

## Federation

For federation to work properly with other Matrix homeservers:

1. Your server must be reachable on port 8448 (or you must configure delegation)
2. DNS must be properly configured with SRV records
3. TLS certificates must be valid for the domain
4. The server_name in homeserver.yaml should match your domain

## Useful Commands

### Creating Users
```bash
# Interactive user creation
docker exec -it synapse-app register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008

# Using shared secret
curl -X POST -H "Content-Type: application/json" \
  -d '{"username":"myuser","password":"mypassword","admin":false,"shared_secret":"YOUR_REGISTRATION_SHARED_SECRET"}' \
  https://matrix.<host>.local/_synapse/admin/v1/register
```

### Database Access
```bash
docker exec -it synapse-database psql -U synapse
```

### Logs
```bash
docker logs synapse-app
docker logs synapse-database
docker logs synapse-redis
```

## References

- [Synapse Documentation](https://matrix-org.github.io/synapse/latest/)
- [Configuration Documentation](https://matrix-org.github.io/synapse/latest/usage/configuration/config_documentation.html)
- [Federation Tester](https://federationtester.matrix.org/)
- [Matrix Specification](https://spec.matrix.org/)
