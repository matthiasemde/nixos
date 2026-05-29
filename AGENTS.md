# AGENTS.md - AI Agents & Automation in Project Pandora

This document catalogs the AI agents, automation systems, and intelligent services deployed within the Project Pandora homelab infrastructure.

## 🤖 Overview

Project Pandora leverages a distributed architecture of containerized services, many of which include AI-driven automation, intelligent monitoring, and adaptive behaviors. The infrastructure is built on NixOS with declarative container orchestration using NixOS modules.

## 🏠 Home Automation Agents

### Home Assistant
- **Service**: `home-assistant`
- **Container**: `ghcr.io/home-assistant/home-assistant:2025.7`
- **Agent Capabilities**: 
  - Smart home device orchestration
  - Automated scene management
  - Sensor data analysis and pattern recognition
  - Voice assistant integration
  - Predictive automation based on usage patterns
- **Configuration**: `/services/home-assistant/config/`
  - `automations.yaml` - Behavioral automation rules
  - `scripts.yaml` - Callable automation sequences  
  - `scenes.yaml` - Environmental state presets
- **Network**: Exposed via Traefik at `home-assistant.emdecloud.de`

## 🔐 Security & Authentication Agents

### Authentik SSO
- **Service**: `authentik`
- **Agent Capabilities**:
  - Identity and access management
  - Behavioral authentication patterns
  - Risk-based access control
  - Session anomaly detection
- **Integration**: Centralized authentication for all services

### Vaultwarden (Bitwarden)
- **Service**: `vaultwarden`  
- **Agent Capabilities**:
  - Password breach monitoring
  - Credential strength analysis
  - Usage pattern detection
- **Security**: SMTP notifications for suspicious activities

## 🌐 Network Intelligence Agents

### AdGuard Home
- **Service**: `adguard`
- **Container**: DNS filtering and monitoring
- **Agent Capabilities**:
  - Intelligent DNS filtering
  - Network traffic pattern analysis
  - Threat detection and blocking
  - Adaptive filtering based on usage patterns
- **Network**: DNS server on port 53

### Traefik Reverse Proxy
- **Service**: `traefik`
- **Container**: `traefik:3.4.3`
- **Agent Capabilities**:
  - Automatic service discovery
  - Dynamic SSL certificate management
  - Load balancing optimization
  - Intelligent routing decisions
- **Configuration**: `/services/traefik/config/traefik.toml`

### Cloudflared Tunnel
- **Service**: `cloudflared`
- **Agent Capabilities**:
  - Secure tunnel management
  - Traffic routing optimization
  - Connection resilience

## 📊 Monitoring & Analytics Agents

### Glances System Monitor
- **Service**: `glances`
- **Agent Capabilities**:
  - Real-time system performance monitoring
  - Resource usage prediction
  - Anomaly detection in system metrics
  - Adaptive alert thresholds

### Homepage Dashboard
- **Service**: `homepage`
- **Container**: `ghcr.io/gethomepage/homepage:v1.3.2`
- **Agent Capabilities**:
  - Service health aggregation
  - Intelligent service status inference
  - Dynamic widget configuration
  - Usage pattern visualization

## 📄 Document Intelligence Agents

### Paperless-ngx
- **Service**: `paperless`
- **Agent Capabilities**:
  - Document content extraction and OCR
  - Automatic document classification
  - Tag recommendation algorithms
  - Search intelligence and relevance scoring
  - Consumer-based workflow automation

### Nextcloud
- **Service**: `nextcloud`
- **Agent Capabilities**:
  - File synchronization intelligence
  - Collaborative filtering
  - Storage optimization
  - Background job scheduling
- **Features**: Cron-based maintenance automation

## 💰 Financial Intelligence Agents

### Firefly III
- **Service**: `firefly`
- **Agent Capabilities**:
  - Transaction categorization
  - Spending pattern analysis
  - Budget recommendation algorithms
  - Financial trend prediction
- **Integration**: Bank account connectivity via APIs

## 📸 Media Intelligence Agents

### Immich
- **Service**: `immich`
- **Agent Capabilities**:
  - Image/video content analysis
  - Facial recognition and clustering
  - Automatic tagging and categorization
  - Duplicate detection algorithms
  - Smart album generation

## 🎮 Game Server Management

### Pterodactyl Panel
- **Service**: `pterodactyl`
- **Agent Capabilities**:
  - Automated game server provisioning
  - Resource scaling based on demand
  - Performance monitoring and optimization
  - Backup automation

## 🔄 Backup & Sync Agents

### Kopia Backup
- **Service**: `kopia`
- **Agent Capabilities**:
  - Intelligent backup scheduling
  - Deduplication algorithms
  - Compression optimization
  - Incremental backup strategies

### Radicale CalDAV/CardDAV
- **Service**: `radicale`
- **Agent Capabilities**:
  - Calendar and contact synchronization
  - Conflict resolution algorithms
  - Data integrity validation

## 🛠 Development & Infrastructure Agents

### FRP (Fast Reverse Proxy)
- **Service**: `frp`
- **Agent Capabilities**:
  - Dynamic tunnel management
  - Connection optimization
  - Failover handling

### VS Code Server
- **Service**: `vscode-server`
- **Agent Capabilities**:
  - Remote development environment
  - Code analysis and suggestions
  - Extension management

## 🔧 Infrastructure Automation

### NixOS Module Architecture
- **Declarative Configuration**: Each service is a plain NixOS module under `services/<name>/default.nix`
- **Automatic Dependency Resolution**: Service interdependencies managed declaratively via `myVirtualization.dependencies`
- **Immutable Deployments**: Reproducible infrastructure deployments via Nix flake locking
- **Secret Management**: Automated secret injection via `sops-nix`

### Container Orchestration
- **Virtualization Module**: `/virtualization/default.nix`
- **Options namespace**: `myVirtualization.{containers, networks, dependencies}`
- **Capabilities**:
  - Automatic Docker network creation
  - Service dependency file provisioning
  - Image reference parsing and validation (`parseDockerImageReference`)
  - Traefik label generation (`mkTraefikLabels`)
  - Container lifecycle management
- **Helper injection**: `mkTraefikLabels` and `parseDockerImageReference` injected into all modules via `_module.args`

### Secret Management Module
- **Module**: `/secret-mgmt/default.nix`
- **Capabilities**:
  - Auto-scans `services/*/secrets/` and `hosts/<hostname>/secrets/` for sops secret files
  - age/YubiKey-based encryption/decryption
  - Environment file and secret file injection at runtime
- **Helper injection**: `getEnvFiles` and `getSecretFile` injected into all modules via `_module.args`

## 🔄 Automation Patterns

### Service Module Shape
Each service module (`services/<name>/default.nix`) receives helpers as function arguments and sets NixOS options:
```nix
{ domain, mkTraefikLabels, getEnvFiles, getSecretFile, ... }:
{
  myVirtualization.containers.<name> = { ... };
  myVirtualization.networks.<name>   = "";
  myVirtualization.dependencies.*   = { ... };
}
```

### Dependency Management
- **Files**: Automatic creation of required data files at activation time
- **Networks**: Dynamic Docker network provisioning via activation scripts
- **Secrets**: Encrypted secrets auto-discovered and mounted at `/run/mysecrets/`

### Update Automation
- **Renovate Integration**: Automated dependency updates via `renovate.json`
- **Container Image Pinning**: All images pinned to specific digests
- **Nix Flake Locking**: Reproducible dependency versions

## 🚀 Agent Interaction Flows

1. **Service Deployment**: NixOS module system aggregates all service modules, provisions containers, networks, and dependency files
2. **Secret Injection**: sops-nix decrypts secrets at activation time and mounts them for containers
3. **Service Discovery**: Traefik automatically discovers and routes services
4. **Health Monitoring**: Glances and Homepage aggregate service health
5. **Authentication**: Authentik provides unified identity management
6. **Backup**: Kopia automatically backs up persistent data
7. **Monitoring**: Home Assistant integrates with infrastructure metrics

## 📈 Future Agent Enhancements

- Integration of LLM-based log analysis agents
- Predictive scaling based on usage patterns
- Automated security response systems
- Enhanced cross-service data correlation
- AI-driven configuration optimization

---

*This infrastructure demonstrates a sophisticated multi-agent system where each containerized service acts as a specialized agent, contributing to an intelligent, self-managing homelab ecosystem.*