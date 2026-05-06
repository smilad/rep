FROM alpine:3.20

ARG XRAY_VERSION=1.8.24

RUN apk add --no-cache ca-certificates openssl tzdata wget unzip && \
    case "$(uname -m)" in \
      x86_64)  ARCH=64 ;; \
      aarch64) ARCH=arm64-v8a ;; \
      armv7l)  ARCH=arm32-v7a ;; \
      *) echo "unsupported arch: $(uname -m)" && exit 1 ;; \
    esac && \
    wget -O /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${ARCH}.zip" && \
    unzip /tmp/xray.zip xray -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/xray && \
    rm /tmp/xray.zip && \
    apk del wget unzip

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
VOLUME /etc/xray

ENTRYPOINT ["/entrypoint.sh"]
