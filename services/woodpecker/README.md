# Woodpecker CI Setup

Woodpecker CI is a lightweight, self-hosted CI/CD platform for automating NixOS deployments.

## Architecture

- **woodpecker-server**: Web UI and API server (port 8000, gRPC 9000)
- **woodpecker-agent**: Pipeline executor with access to Docker and Nix

## Setup Instructions

### 1. Create GitHub OAuth Application

1. Go to https://github.com/settings/developers
2. Click "New OAuth App"
3. Fill in:
   - **Application name**: `Woodpecker CI - Pandora`
   - **Homepage URL**: `https://ci.emdecloud.de`
   - **Authorization callback URL**: `https://ci.emdecloud.de/authorize`
4. Click "Register application"
5. Note down the **Client ID** and generate a **Client Secret**

### 2. Generate Secrets

```bash
# Generate agent secret (shared between server and agent)
openssl rand -hex 32

# Optional: Generate webhook secret
openssl rand -hex 32
```

### 3. Configure Secrets

Add the values you generated:
- `WOODPECKER_GITHUB_CLIENT`: Your GitHub OAuth Client ID
- `WOODPECKER_GITHUB_SECRET`: Your GitHub OAuth Client Secret
- `WOODPECKER_AGENT_SECRET`: Random hex string (same in both server and agent)
- `WOODPECKER_WEBHOOK_SECRET`: Random hex string

### 4. Update flake.nix

Add woodpecker to your main flake inputs and services list:

```nix
# In inputs section
woodpecker.url = "path:./services/woodpecker";

# In modules specialArgs services list
woodpecker
```

### 5. Rebuild NixOS

```bash
sudo nixos-rebuild switch --flake .#mahler
```

### 6. Access Woodpecker

1. Navigate to https://ci.emdecloud.de
2. Login with GitHub
3. The first user to login becomes admin (should be your GitHub account)
4. Activate your `Pandora` repository

### 7. Configure GitHub Webhook

Woodpecker automatically configures webhooks when you activate a repository, but verify:

1. Go to your GitHub repo: https://github.com/matthiasemde/Pandora/settings/hooks
2. Check for webhook pointing to `https://ci.emdecloud.de/hook`
3. Events should include: Push, Pull Request
