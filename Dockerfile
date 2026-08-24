FROM repocket/repocket:latest

ENV TZ=Asia/Shanghai \
    CLASH_SUB_URL="" \
    RP_EMAIL="" \
    RP_API_KEY="" \
    HTTP_PROXY=http://127.0.0.1:7890 \
    HTTPS_PROXY=http://127.0.0.1:7890 \
    http_proxy=http://127.0.0.1:7890 \
    https_proxy=http://127.0.0.1:7890 \
    ALL_PROXY=socks5://127.0.0.1:7891 \
    NO_PROXY=localhost,127.0.0.1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        curl \
        ca-certificates \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64) MIHOMO_ARCH=amd64 ;; \
      aarch64|arm64) MIHOMO_ARCH=arm64 ;; \
      armv7l) MIHOMO_ARCH=armv7 ;; \
      *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/MetaCubeX/mihomo/releases/download/v1.19.30/mihomo-linux-${MIHOMO_ARCH}-v1.19.30.gz" -o /tmp/mihomo.gz && \
    gzip -dc /tmp/mihomo.gz > /usr/local/bin/mihomo && \
    chmod +x /usr/local/bin/mihomo && \
    rm -f /tmp/mihomo.gz

EXPOSE 7890 7891 9090

CMD ["/bin/bash", "-lc", "set -eu; mkdir -p /etc/mihomo; cat > /etc/mihomo/config.yaml <<'EOF'\nmixed-port: 7890\nsocks-port: 7891\nallow-lan: true\nbind-address: \"*\"\nmode: rule\nlog-level: info\nexternal-controller: \"0.0.0.0:9090\"\nsecret: \"\"\n\nproxy-groups:\n  - name: \"PROXY\"\n    type: select\n    proxies:\n      - \"DIRECT\"\n\nrules:\n  - MATCH,DIRECT\nEOF\nif [ -n \"${CLASH_SUB_URL:-}\" ]; then\n  echo \"Downloading Mihomo subscription...\";\n  curl -fsSL \"${CLASH_SUB_URL}\" -o /etc/mihomo/subscription.yaml || echo \"Subscription download failed, using default config\";\n  if [ -s /etc/mihomo/subscription.yaml ]; then\n    cp /etc/mihomo/subscription.yaml /etc/mihomo/config.yaml;\n  fi;\nfi;\nexport HTTP_PROXY=\"http://127.0.0.1:7890\";\nexport HTTPS_PROXY=\"http://127.0.0.1:7890\";\nexport http_proxy=\"http://127.0.0.1:7890\";\nexport https_proxy=\"http://127.0.0.1:7890\";\nexport ALL_PROXY=\"socks5://127.0.0.1:7891\";\nexport NO_PROXY=\"localhost,127.0.0.1\";\n/usr/local/bin/mihomo -d /etc/mihomo -f /etc/mihomo/config.yaml > /var/log/mihomo.log 2>&1 &\nfor i in $(seq 1 30); do\n  if curl -fsS http://127.0.0.1:9090 >/dev/null 2>&1; then\n    break;\n  fi;\n  sleep 1;\ndone;\nif [ -z \"${RP_EMAIL:-}\" ] || [ -z \"${RP_API_KEY:-}\" ]; then\n  echo \"Missing RP_EMAIL or RP_API_KEY environment variables\";\n  exit 1;\nfi;\nexec env RP_EMAIL=\"${RP_EMAIL}\" RP_API_KEY=\"${RP_API_KEY}\" repocket" ]
