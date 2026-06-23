FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="paperclip-week2-day5-integration-app"
LABEL org.opencontainers.image.description="Static integration app for Week 2 Day 5 Docker operations practice"

COPY html/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
