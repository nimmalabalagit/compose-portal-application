# ── Stage 1: Build React app ──────────────────────────────────────────────────
# WHY node:20-alpine: smallest Node image, reduced attack surface for Trivy scans
FROM node:20-alpine AS builder
WORKDIR /app

# WHY copy package.json first:
# Docker layer cache — if package.json doesn't change, npm ci is cached.
# Only changed source code triggers a rebuild of subsequent layers.
COPY package*.json ./
RUN npm ci --quiet

COPY . .
# Vite build produces /app/dist with content-hashed filenames
RUN npx vite build

# ── Stage 2: nginx serving React ──────────────────────────────────────────────
# WHY nginx:1.27-alpine (not node): Runtime needs only a static file server.
# Node runtime (~180MB) is unnecessary overhead for serving HTML/JS/CSS files.
FROM nginx:1.27-alpine AS runtime

# WHY non-root nginx:
# K8s SecurityContext runAsNonRoot=true rejects containers running as root (UID 0).
# nginx can serve on port 80 with a non-root user using the workaround below.
RUN addgroup -S webgroup && adduser -S webuser -G webgroup \
    && mkdir -p /var/cache/nginx /var/run \
    && chown -R webuser:webgroup /var/cache/nginx /var/run /etc/nginx/conf.d \
    && touch /var/run/nginx.pid \
    && chown webuser:webgroup /var/run/nginx.pid

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
RUN chown -R webuser:webgroup /usr/share/nginx/html

USER webuser
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
    CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
