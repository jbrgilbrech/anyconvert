FROM node:24-bookworm-slim AS web-assets

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY docs ./docs
COPY scripts ./scripts
RUN chmod +x ./scripts/sync-web-vendor.sh && npm run sync:web-vendor

FROM nginx:1.27-alpine AS web-runtime

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=web-assets /app/docs /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
