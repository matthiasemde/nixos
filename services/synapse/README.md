# Matrix Synapse Service

This directory contains the NixOS configuration for the Matrix Synapse homeserver with admin interface.

## Architecture

The service consists of six containers:
- **synapse-app**: The main Matrix Synapse server
- **synapse-database**: PostgreSQL database for persistent storage
- **synapse-redis**: Redis for caching and replication
- **synapse-admin**: Web-based admin interface for managing the homeserver
- **matrix-auth-app**: Matrix Authentication Service (next-gen auth per MSC3861)
- **matrix-auth-database**: PostgreSQL database for MAS authentication data

## Next-Generation Authentication

This setup includes **Matrix Authentication Service (MAS)** which implements [MSC3861](https://github.com/matrix-org/matrix-doc/pull/3861) for next-generation Matrix authentication. MAS provides:

- **Modern OAuth2/OIDC flows** replacing legacy Matrix authentication
- **Seamless Authentik integration** with your existing SSO infrastructure
- **Enhanced security** with proper token management and session handling
- **Future-proof architecture** aligned with Matrix specification evolution

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

#### Core Synapse Secrets
1. **POSTGRES_PASSWORD.env.age**: PostgreSQL database password
2. **SYNAPSE_REGISTRATION_SHARED_SECRET.env.age**: For registering users via the API
3. **SYNAPSE_MACAROON_SECRET_KEY.env.age**: For generating access tokens
4. **SYNAPSE_FORM_SECRET.env.age**: For securing forms
5. **AUTHENTIK_CLIENT_ID.env.age**: Authentik OAuth2 client ID for SSO
6. **AUTHENTIK_CLIENT_SECRET.env.age**: Authentik OAuth2 client secret for SSO

#### Matrix Authentication Service (MAS) Secrets
7. **MAS_POSTGRES_PASSWORD.env.age**: MAS PostgreSQL database password
8. **MAS_ENCRYPTION_KEY.env.age**: MAS data encryption key (32 random bytes, base64 encoded)
9. **MAS_SIGNING_KEY.env.age**: MAS JWT signing key (RS256 private key, PEM format)
10. **MAS_KEY_ID.env.age**: MAS signing key identifier (random string)
11. **MAS_MATRIX_SECRET.env.age**: Shared secret between MAS and Synapse
12. **MAS_MATRIX_CLIENT_ID.env.age**: OAuth2 client ID for Synapse -> MAS communication
13. **MAS_MATRIX_CLIENT_SECRET.env.age**: OAuth2 client secret for Synapse -> MAS
14. **MAS_ADMIN_TOKEN.env.age**: Admin token for MAS administrative operations
15. **MAS_AUTHENTIK_PROVIDER_ID.env.age**: ULID identifier for Authentik provider in MAS

## Traefik Integration

The service is configured with **enhanced security routing** following Synapse documentation best practices:

### Matrix Server Routes
- **Public Client API**: `https://matrix.<domain>` - Restricted to `/_matrix` and `/_synapse/client` paths only
- **Admin API**: `http://matrix.<domain>/_synapse/admin` - Accessible for administration (requires authentication)
- **Local Access**: `http://matrix.<host>.local` - Full access for local administration

### Matrix Authentication Service Routes
- **Public Access**: `https://matrix-auth.<domain>` - MAS authentication interface with Authentik SSO
- **Local Access**: `http://matrix-auth.<host>.local` - Direct local access

### Synapse Admin Interface
- **Local Access**: `http://synapse-admin.<host>.local` - Direct local access

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


### Required Setup Steps

- [x] **Generate and encrypt all required secrets** (see Secrets section above)
- [x] **Create data directories**:
  ```bash
  sudo mkdir -p /data/services/synapse/{db,redis,data/media_store,data/keys}
  sudo chown -R 991:991 /data/services/synapse/data  # Synapse runs as UID 991
  ```

- [x] **Generate signing keys**: On first run, Synapse will auto-generate signing keys in `/data/services/synapse/app/keys/`



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
