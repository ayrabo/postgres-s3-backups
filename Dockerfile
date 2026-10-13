ARG NODE_VERSION='22'

FROM node:${NODE_VERSION}-alpine3.21 AS build

ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NPM_CONFIG_FUND=false

WORKDIR /app

COPY package*.json tsconfig.json ./
COPY src ./src

RUN npm ci && \
    npm run build && \
    npm prune --production

FROM node:${NODE_VERSION}-alpine3.21

WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

ARG PG_VERSION='17'

RUN apk add --update --no-cache postgresql${PG_VERSION}-client

# Wait up to ~60s for postgres: on dev/demo it sleeps when idle (Railway Serverless, ayrabo#1701), and the first
# connection attempt only wakes it.
CMD i=0; until pg_isready --dbname="$BACKUP_DATABASE_URL"; do \
      i=$((i+1)); [ "$i" -ge 30 ] && exit 1; sleep 2; \
    done; \
    pg_dump --version && \
    node dist/index.js
