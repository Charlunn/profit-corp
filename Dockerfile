# =============================================================================
# Profit-Corp Dockerfile
# =============================================================================
# Builds an OpenCLAW image with profit-corp config pre-applied.
# Config path substitution and agent registration happen at container start
# via the entrypoint script below.
# =============================================================================

FROM node:24-slim

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    ca-certificates \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# ── Create app user ───────────────────────────────────────────────────────────
RUN useradd -m -s /bin/bash openclaw
USER openclaw
WORKDIR /home/openclaw

# ── Install OpenCLAW globally (as app user) ───────────────────────────────────
RUN npm install -g openclaw@latest

# ── Create corp directory structure ───────────────────────────────────────────
# Source files are baked in; data volumes are mounted at runtime (see compose).
COPY --chown=openclaw:openclaw . /home/openclaw/profit-corp

# ── Create state dir ──────────────────────────────────────────────────────────
RUN mkdir -p /home/openclaw/.openclaw/agents

# ── Entrypoint script ─────────────────────────────────────────────────────────
COPY --chown=openclaw:openclaw docker-entrypoint.sh /home/openclaw/docker-entrypoint.sh
RUN chmod +x /home/openclaw/docker-entrypoint.sh

EXPOSE 18789

ENTRYPOINT ["/home/openclaw/docker-entrypoint.sh"]
