# One image for every role: setup (migrations and seed), api, worker and web.
# Build arg NPM_REGISTRY switches the npm registry (e.g. https://registry.npmmirror.com in mainland China),
# NODE_IMAGE the base image when Docker Hub is out of reach (e.g. docker.m.daocloud.io/library/node:24-trixie-slim),
# APT_MIRROR the Debian mirror in place of http://deb.debian.org (e.g. http://mirrors.aliyun.com).
ARG NODE_IMAGE=node:24-trixie-slim
FROM ${NODE_IMAGE} AS base
ARG APT_MIRROR=
WORKDIR /app
# pg_dump for the optional database backups (Debian's client matches the PostgreSQL 17 server in compose).
RUN if [ -n "$APT_MIRROR" ]; then sed -i "s|http://deb.debian.org|$APT_MIRROR|g" /etc/apt/sources.list.d/debian.sources; fi \
 && apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client ca-certificates \
 && rm -rf /var/lib/apt/lists/*

FROM base AS build
ARG NPM_REGISTRY=
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/
COPY apps/web/package.json apps/web/
COPY apps/worker/package.json apps/worker/
COPY packages/backend/package.json packages/backend/
COPY packages/contracts/package.json packages/contracts/
COPY industry/package.json industry/
COPY site/package.json site/
RUN npm ci --no-audit --no-fund ${NPM_REGISTRY:+--registry=$NPM_REGISTRY}
COPY . .
RUN npm run build -w @aihot/web && npm prune --omit=dev --no-audit --no-fund

FROM base
ENV NODE_ENV=production
COPY --from=build --chown=node:node /app /app
RUN mkdir -p /data && chown node:node /data
USER node
EXPOSE 3000
CMD ["node", "apps/web/server.ts"]
