#!/usr/bin/env bash
set -e

# ==========================================
# pxz-mtpmulti-interactive.sh  (by pxzone)
# Interactive installer for MTProto proxies
# - Default mode: 6 proxies with default FakeTLS (only simple list printed)
# - Custom FakeTLS mode: user picks 1..10 domains; builds exactly that many proxies
# - Optional custom ports
# - Optional advertising TAG (from @MTProxybot)
# - Persistent secrets per instance
# - Auto-restart on reboot (Docker)
# ==========================================

STATE_BASE="/opt/mtproto-multi"
DEFAULT_HOSTNAME=""   # if empty, use IPv4 in links
# Up to 10 default ports (used when user doesn't provide custom ports)
DEFAULT_PORTS=(443 8443 9443 10443 11443 12443 13443 14443 15443 16443)
# Default FakeTLS domains (cycled if needed)
DEFAULT_DOMAINS=(www.divar.ir www.aparat.com www.rubika.ir www.torob.com www.snapp.ir www.tap30.ir www.digikala.com www.sheypoor.com www.zoomit.ir www.bama.ir)

# Optional: force platform (usually NOT needed). Examples: linux/amd64 or linux/arm64
FORCE_PLATFORM="${FORCE_PLATFORM:-}"

# --- tools ---
if ! command -v curl >/dev/null 2>&1; then
  apt-get update && apt-get install -y curl
fi
if ! command -v docker >/dev/null 2>&1; then
  apt-get update && apt-get install -y docker.io
fi
command -v openssl >/dev/null 2>&1 || apt-get install -y openssl
command -v ufw >/dev/null 2>&1 || true

# --- IPv4 detection ---
IPV4="$(curl -4 -s https://ifconfig.me || true)"
if [ -z "$IPV4" ]; then
  echo "Couldn't detect public IPv4. Enter it manually (e.g., 1.2.3.4):"
  read -r IPV4
fi

# --- hostname for links ---
echo "Enter Hostname (subdomain) to show in user links (Press Enter to use IPv4):"
read -r HOSTNAME
if [ -z "${HOSTNAME}" ]; then
  HOSTNAME="${DEFAULT_HOSTNAME}"
fi

# --- FakeTLS mode: default or custom? ---
CUSTOM_TLS="no"
echo "Do you want to provide custom FakeTLS domains? (y/N)"
read -r ANS_TLS
ANS_TLS="${ANS_TLS,,}"
if [ "$ANS_TLS" = "y" ] || [ "$ANS_TLS" = "yes" ]; then
  CUSTOM_TLS="yes"
fi

# --- COUNT and DOMAINS based on mode ---
COUNT=6
DOMAINS=()
if [ "$CUSTOM_TLS" = "yes" ]; then
  # Ask how many proxies to build: 1..10
  while : ; do
    echo "How many proxies do you want to create? (1-10)"
    read -r COUNT
    # ensure COUNT is integer 1..10
    if [[ "$COUNT" =~ ^[0-9]+$ ]] && [ "$COUNT" -ge 1 ] && [ "$COUNT" -le 10 ]; then
      break
    fi
    echo "Please enter a number between 1 and 10."
  done
  echo "Enter $COUNT FakeTLS domain(s) separated by commas (e.g., www.divar.ir,www.aparat.com,...)"
  read -r CSV_DOMAINS
  IFS=',' read -r -a DOMAINS <<< "$CSV_DOMAINS"
  # trim spaces
  for i in "${!DOMAINS[@]}"; do DOMAINS[$i]="${DOMAINS[$i]//[[:space:]]/}"; done
  if [ ${#DOMAINS[@]} -ne $COUNT ]; then
    echo "You must provide exactly $COUNT domains." >&2; exit 1
  fi
else
  # Default mode: 6 proxies; take first 6 default domains (cycle if fewer than COUNT)
  COUNT=6
  for i in $(seq 1 $COUNT); do
    idx=$(( (i-1) % ${#DEFAULT_DOMAINS[@]} ))
    DOMAINS+=("${DEFAULT_DOMAINS[$idx]}")
  done
fi

# --- Ports: default or custom? must match COUNT if custom ---
PORTS=()
echo "Do you want to set custom ports? (y/N)"
read -r ANS_PORTS
ANS_PORTS="${ANS_PORTS,,}"
if [ "$ANS_PORTS" = "y" ] || [ "$ANS_PORTS" = "yes" ]; then
  echo "Enter exactly $COUNT port(s) separated by commas (e.g., 443,8443,9443,10443,11443,12443):"
  read -r CSV_PORTS
  IFS=',' read -r -a PORTS <<< "$CSV_PORTS"
  for i in "${!PORTS[@]}"; do PORTS[$i]="${PORTS[$i]//[[:space:]]/}"; done
  if [ ${#PORTS[@]} -ne $COUNT ]; then
    echo "You must provide exactly $COUNT ports." >&2; exit 1
  fi
else
  # Take first COUNT from DEFAULT_PORTS
  if [ ${#DEFAULT_PORTS[@]} -lt $COUNT ]; then
    echo "Not enough default ports for COUNT=$COUNT. Reduce count or extend DEFAULT_PORTS." >&2
    exit 1
  fi
  for i in $(seq 1 $COUNT); do
    PORTS+=("${DEFAULT_PORTS[$((i-1))]}")
  done
fi

# --- prepare ---
mkdir -p "$STATE_BASE"
if command -v ufw >/dev/null 2>&1; then
  for p in "${PORTS[@]}"; do ufw allow ${p}/tcp >/dev/null 2>&1 || true; ufw allow ${p}/udp >/dev/null 2>&1 || true; done
fi

# Build docker run base args (platform optional)
DOCKER_PLATFORM_ARGS=()
if [ -n "$FORCE_PLATFORM" ]; then
  DOCKER_PLATFORM_ARGS=(--platform "$FORCE_PLATFORM")
fi

# --- create or re-run containers (initially WITHOUT TAG) ---
LINKS_SIMPLE=()
LINKS_GROUPED=()
SECRETS_RAW=()   # store raw secrets (no 'dd') per instance to help user register in @MTProxybot

for i in $(seq 1 $COUNT); do
  NAME="mtp$i"
  PORT="${PORTS[$((i-1))]}"
  DOMAIN="${DOMAINS[$((i-1))]}"
  SDIR="$STATE_BASE/$NAME"
  mkdir -p "$SDIR"

  if [ -f "$SDIR/secret" ]; then
    SECRET="$(cat "$SDIR/secret")"
  else
    SECRET="$(openssl rand -hex 16)"
    printf "%s" "$SECRET" > "$SDIR/secret"
  fi

  docker rm -f "$NAME" >/dev/null 2>&1 || true

  docker run -d --name "$NAME" --restart=always \
    -p ${PORT}:443 \
    -e SECRET="$SECRET" \
    -e TLSPORT=443 \
    -e FAKE_TLS_DOMAIN="$DOMAIN" \
    -e NAT_PUBLIC_IP="$IPV4" \
    "${DOCKER_PLATFORM_ARGS[@]}" \
    telegrammessenger/proxy:latest >/dev/null

  SERVER_LABEL="${HOSTNAME:-$IPV4}"
  LINK="https://t.me/proxy?server=${SERVER_LABEL}&port=${PORT}&secret=dd${SECRET}"

  LINKS_SIMPLE+=("$LINK")
  if [ "$CUSTOM_TLS" = "yes" ]; then
    LINKS_GROUPED+=("FakeTLS: ${DOMAIN}\n${LINK}\n")
  fi
  SECRETS_RAW+=("$SECRET")
done

echo
echo "================= List — User links (https) ================="
for L in "${LINKS_SIMPLE[@]}"; do echo "$L"; done

if [ "$CUSTOM_TLS" = "yes" ]; then
  echo
  echo "================= List — Grouped by FakeTLS ================="
  for G in "${LINKS_GROUPED[@]}"; do echo -e "$G"; done
fi

echo
echo "NOTE:"
echo "- If you provided a Hostname, ensure A record points to ${IPV4}."
echo "- Containers have --restart=always and will auto-start after reboot."

# --- Advertising TAG flow ---
echo
echo "Do you want to enable Telegram advertising TAG now? (y/N)"
read -r ANS_TAG
ANS_TAG="${ANS_TAG,,}"

if [ "$ANS_TAG" = "y" ] || [ "$ANS_TAG" = "yes" ]; then
  # Help the user register at @MTProxybot using the FIRST instance params
  FIRST_PORT="${PORTS[0]}"
  FIRST_SECRET_RAW="${SECRETS_RAW[0]}"
  echo
  echo "=== How to get TAG from @MTProxybot ==="
  echo "1) Open @MTProxybot in Telegram"
  echo "2) Send /newproxy"
  echo "3) Provide the following values:"
  echo "   - IP:   ${IPV4}"
  echo "   - Port: ${FIRST_PORT}"
  echo "   - Secret (RAW, WITHOUT 'dd'): ${FIRST_SECRET_RAW}"
  echo "4) Copy the TAG that bot gives you and paste it below."
  echo
  echo "Paste the TAG here (or press Enter to skip):"
  read -r INPUT_TAG
  USE_TAG=""
  if [ -n "$INPUT_TAG" ]; then
    USE_TAG="$INPUT_TAG"
  fi

  if [ -n "$USE_TAG" ]; then
    echo
    echo "Applying TAG to all containers..."
    for i in $(seq 1 $COUNT); do
      NAME="mtp$i"
      PORT="${PORTS[$((i-1))]}"
      DOMAIN="${DOMAINS[$((i-1))]}"
      SECRET="$(cat "$STATE_BASE/$NAME/secret")"

      docker rm -f "$NAME" >/dev/null 2>&1 || true
      docker run -d --name "$NAME" --restart=always \
        -p ${PORT}:443 \
        -e SECRET="$SECRET" \
        -e TAG="$USE_TAG" \
        -e TLSPORT=443 \
        -e FAKE_TLS_DOMAIN="$DOMAIN" \
        -e NAT_PUBLIC_IP="$IPV4" \
        "${DOCKER_PLATFORM_ARGS[@]}" \
        telegrammessenger/proxy:latest >/dev/null
    done
    echo "Done. TAG applied. Users should now see your channel banner when connected."
  else
    echo "No TAG provided. You can re-run this script later to add it."
  fi
else
  echo "Skipping TAG setup. You can re-run this script later to add it."
fi
