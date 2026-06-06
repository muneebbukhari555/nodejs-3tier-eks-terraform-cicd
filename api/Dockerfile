# Stage 1 — install production dependencies in isolation.
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM node:22-alpine AS runtime
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app

RUN apk add --no-cache tini

COPY --chown=node:node --from=deps /app/node_modules ./node_modules

COPY --chown=node:node . .

USER node
EXPOSE 3000

# Health check — used by docker compose and surfaced in `docker ps`.
# /api/status opens a real DB connection; a 200 confirms both app and DB are up.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT}/api/status > /dev/null || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "./bin/www"]
