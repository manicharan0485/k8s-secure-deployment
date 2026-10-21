# Minimal hardened reference image: serves the /healthz and /ready endpoints
# the Helm chart's probes expect. Replace with your real application.
# Runs as non-root (uid 101) and works with readOnlyRootFilesystem: all writable
# paths are under /tmp, which the chart mounts as an emptyDir.
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Pull in fixed versions of OS packages not yet in the base image.
USER root
RUN apk upgrade --no-cache

COPY app/nginx.conf /etc/nginx/nginx.conf

USER 101
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
