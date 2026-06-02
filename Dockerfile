# ─── Build stage : Flutter web ────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.27.0 AS builder

# URL du backend — surcharger via: docker build --build-arg API_BASE_URL=https://mondomaine.com
ARG API_BASE_URL=http://localhost:3000

WORKDIR /app

# Copier les manifestes de dépendances en premier (cache layer)
COPY pubspec.yaml pubspec.lock ./

RUN flutter pub get

# Copier le reste du code
COPY . .

# Build Flutter web (release, treeshaking activé)
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://www.gstatic.com/flutter-canvaskit/

# ─── Serve stage : nginx alpine ───────────────────────────────────────────────
FROM nginx:1.25-alpine AS runner

# Utilisateur non-root
RUN addgroup -g 1001 proxima && \
    adduser -u 1001 -G proxima -s /bin/sh -D proxima

# Copier le build Flutter web
COPY --from=builder /app/build/web /usr/share/nginx/html

# Config nginx pour SPA (Single Page App)
COPY docker/nginx-frontend.conf /etc/nginx/conf.d/default.conf

# Permissions
RUN chown -R proxima:proxima /usr/share/nginx/html && \
    chown -R proxima:proxima /var/cache/nginx && \
    chown -R proxima:proxima /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown proxima:proxima /var/run/nginx.pid

USER proxima
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:80 || exit 1

CMD ["nginx", "-g", "daemon off;"]
