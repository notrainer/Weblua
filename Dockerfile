# syntax=docker/dockerfile:1

FROM docker.io/library/node:22-slim AS build
WORKDIR /app

# package-lock.json is written by npm 11. Node 22 bundles npm 10, whose `npm ci`
# rejects npm 11 lockfiles that nest optional peers (such as @emnapi/*) instead
# of hoisting them, so validate the lockfile with the npm major that wrote it.
RUN npm install -g npm@11

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
ARG VITE_PLAUSIBLE_DOMAIN=""
ARG VITE_SENTRY_DSN=""
RUN npm run build

FROM docker.io/library/nginx:alpine
LABEL org.opencontainers.image.source="https://github.com/notrainer/Weblua" \
      org.opencontainers.image.licenses="MIT"
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/
