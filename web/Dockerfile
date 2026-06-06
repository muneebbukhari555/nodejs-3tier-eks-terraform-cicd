####### Dockerfile for Node.js Express app #########
FROM node:26.3-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Stage 2: minimal runtime image. Only the app + prod node_modules.
FROM node:26.3-alpine AS runtime
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app

RUN apk add --no-cache tini

COPY --chown=node:node --from=deps /app/node_modules ./node_modules
COPY --chown=node:node . .

USER node
EXPOSE 3000

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "./bin/www"]
