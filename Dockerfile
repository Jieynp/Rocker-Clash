# syntax=docker/dockerfile:1
FROM metacubex/mihomo:v1.19.30 AS mihomo

FROM repocket/repocket:latest

USER root
COPY --from=mihomo /mihomo /mihomo
RUN mkdir -p /root/.config/mihomo \
    && cat > /usr/local/bin/repocket-mihomo-entrypoint <<'EOF'
#!/bin/sh
set -eu

: "${RP_EMAIL:?RP_EMAIL is required}"
: "${RP_API_KEY:?RP_API_KEY is required}"
: "${CONFIG_YAML_B64:?CONFIG_YAML_B64 is required}"

config_dir=/root/.config/mihomo
mkdir -p "$config_dir"
printf '%s' "$CONFIG_YAML_B64" | base64 -d > "$config_dir/config.yaml"

/mihomo -d "$config_dir" &
mihomo_pid=$!

cleanup() {
    kill "$mihomo_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 2
if ! kill -0 "$mihomo_pid" 2>/dev/null; then
    echo 'Mihomo exited before Repocket could start' >&2
    exit 1
fi

export HTTP_PROXY="${MIHOMO_HTTP_PROXY}"
export HTTPS_PROXY="${MIHOMO_HTTP_PROXY}"
export ALL_PROXY="${MIHOMO_SOCKS_PROXY}"
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export all_proxy="$ALL_PROXY"

exec node /app/dist/index.js
EOF
RUN sed -i 's/\r$//' /usr/local/bin/repocket-mihomo-entrypoint \
    && chmod 0755 /mihomo /usr/local/bin/repocket-mihomo-entrypoint
RUN test -x /usr/local/bin/repocket-mihomo-entrypoint

ENV MIHOMO_HTTP_PROXY=http://127.0.0.1:7890 \
    MIHOMO_SOCKS_PROXY=socks5h://127.0.0.1:7891

EXPOSE 9090 7890 7891
ENTRYPOINT ["/bin/sh", "/usr/local/bin/repocket-mihomo-entrypoint"]
