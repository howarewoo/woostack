FROM node:22-alpine AS base
RUN corepack enable && corepack prepare pnpm@10.30.1

FROM base AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/api/package.json apps/api/
COPY packages/ packages/
RUN pnpm install --frozen-lockfile
COPY apps/api/ apps/api/
RUN pnpm turbo build --filter=api
RUN pnpm --filter api deploy /app/pruned --prod

FROM base AS runtime
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=build --chown=appuser:appgroup /app/pruned/dist ./dist
COPY --from=build --chown=appuser:appgroup /app/pruned/package.json ./
COPY --from=build --chown=appuser:appgroup /app/pruned/node_modules ./node_modules
USER appuser
EXPOSE 3100
CMD ["node", "dist/index.js"]
