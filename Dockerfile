FROM nginx:mainline-alpine-slim AS builder

# Install necessary tools
RUN apk update && apk add --no-cache wget unzip curl build-base gcc

# --------------------------------------------------------
# Nginx Configuration (Move to builder stage)
# --------------------------------------------------------
COPY nginx.conf /etc/nginx/nginx.conf
# --------------------------------
# Golang Compilation
# --------------------------------
WORKDIR /app
ARG TARGETARCH

# Install necessary packages
COPY . .

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"

# Build the go application
RUN go build -o build/x-ui main.go
RUN ./DockerInit.sh "$TARGETARCH"

# Configure fail2ban
RUN rm -f /etc/fail2ban/jail.d/alpine-ssh.conf \
  && cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local \
  && sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf

# =====================================================
# Start New Stage
# =====================================================
FROM nginx:mainline-alpine-slim

ENV TZ=Asia/Tehran

RUN apk add --no-cache --update \
    ca-certificates \
    tzdata \
    fail2ban \
    bash

COPY --from=builder /etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/build/ /app/
COPY --from=builder /app/DockerEntrypoint.sh /app/
COPY --from=builder /app/x-ui.sh /usr/bin/x-ui
COPY --from=builder /app/config.json /app/bin

# Set permissions and entrypoint
RUN chmod +x \
    /app/DockerEntrypoint.sh \
    /app/x-ui \
    /usr/bin/x-ui

VOLUME ["/etc/x-ui"]
CMD ["./x-ui"]
ENTRYPOINT ["/app/DockerEntrypoint.sh"]

RUN chmod go-w /app/bin/config.json
