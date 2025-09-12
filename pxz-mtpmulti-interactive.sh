#!/usr/bin/env bash
set -e

# =======================
# pxz-mtpmulti-interactive.sh
# ساخت خودکار 6 پروکسی MTProto با انتخاب تعاملی پورت‌ها، FakeTLS و TAG
# نویسنده: pxzone
# =======================

COUNT=6
STATE_BASE="/opt/mtproto-multi"
DEFAULT_PORTS=(443 8443 9443 10443 11443 12443)
DEFAULT_DOMAINS=(www.divar.ir www.aparat.com www.rubika.ir www.torob.com www.snapp.ir www.tap30.ir)
DEFAULT_TAG="19a9dcf11a6baa0a719a0985eb214849"   # تگ تبلیغ پیش‌فرض شما
DEFAULT_HOSTNAME=""  # اگر خالی بماند در لینک‌ها IP استفاده می‌شود

# ابزارها
if ! command -v curl >/dev/null 2>&1; then
  apt-get update && apt-get install -y curl
fi
if ! command -v docker >/dev/null 2>&1; then
  apt-get update && apt-get install -y docker.io
fi
command -v openssl >/dev/null 2>&1 || apt-get install -y openssl
command -v ufw >/dev/null 2>&1 || true

# IPv4
IPV4="$(curl -4 -s https://ifconfig.me || true)"
if [[ -z "$IPV4" ]]; then
  echo "IPv4 عمومی پیدا نشد. دستی وارد کن (مثلاً 1.2.3.4):"
  read -r IPV4
fi

echo "Hostname (ساب‌دامین) برای استفاده در لینک‌ها را وارد کن (Enter = استفاده از IP):"
read -r HOSTNAME
if [[ -z "${HOSTNAME}" ]]; then
  HOSTNAME="${DEFAULT_HOSTNAME}"
fi

# پورت‌ها
echo "می‌خوای پورت‌ها را خودت تعیین کنی؟ (y/N)"
read -r ANS_PORTS
ANS_PORTS="${ANS_PORTS,,}"
PORTS=("${DEFAULT_PORTS[@]}")
if [[ "$ANS_PORTS" == "y" || "$ANS_PORTS" == "yes" ]]; then
  echo "6 پورت را با ویرگول جدا وارد کن (مثلاً: 443,8443,9443,10443,11443,12443):"
  read -r CSV_PORTS
  IFS=',' read -r -a PORTS <<< "$CSV_PORTS"
  # حذف فاصله‌ها
  for i in "${!PORTS[@]}"; do PORTS[$i]="${PORTS[$i]//[[:space:]]/}"; done
  if [[ ${#PORTS[@]} -ne $COUNT ]]; then
    echo "تعداد پورت‌ها باید $COUNT تا باشد." >&2; exit 1
  fi
fi

# FakeTLS
echo "می‌خوای FakeTLS سفارشی بدی؟ (y/N)"
read -r ANS_TLS
ANS_TLS="${ANS_TLS,,}"
DOMAINS=("${DEFAULT_DOMAINS[@]}")
if [[ "$ANS_TLS" == "y" || "$ANS_TLS" == "yes" ]]; then
  echo "6 دامنه FakeTLS با ویرگول جدا بده (مثلاً: www.divar.ir,www.aparat.com,...):"
  read -r CSV_DOMAINS
  IFS=',' read -r -a DOMAINS <<< "$CSV_DOMAINS"
  for i in "${!DOMAINS[@]}"; do DOMAINS[$i]="${DOMAINS[$i]//[[:space:]]/}"; done
  if [[ ${#DOMAINS[@]} -ne $COUNT ]]; then
    echo "تعداد دامنه‌ها باید $COUNT تا باشد." >&2; exit 1
  fi
fi

# TAG
USE_TAG="$DEFAULT_TAG"
echo "می‌خوای TAG تبلیغاتی اختصاصی بزاری؟ (y/N)  (اگر نه، از تگ پیش‌فرض استفاده می‌شود)"
read -r ANS_TAG
ANS_TAG="${ANS_TAG,,}"
if [[ "$ANS_TAG" == "y" || "$ANS_TAG" == "yes" ]]; then
  echo "TAG دریافتی از @MTProxybot را وارد کن:"
  read -r USE_TAG
  if [[ -z "$USE_TAG" ]]; then
    echo "TAG خالی است. از تگ پیش‌فرض استفاده می‌شود."
    USE_TAG="$DEFAULT_TAG"
  fi
fi

# آماده‌سازی
mkdir -p "$STATE_BASE"
if command -v ufw >/dev/null 2>&1; then
  for p in "${PORTS[@]}"; do ufw allow ${p}/tcp >/dev/null 2>&1 || true; ufw allow ${p}/udp >/dev/null 2>&1 || true; done
fi

# ساخت/ری‌ران کانتینرها
LINKS_SIMPLE=()
LINKS_GROUPED=()

for i in $(seq 1 $COUNT); do
  NAME="mtp$i"
  PORT="${PORTS[$((i-1))]}"
  DOMAIN="${DOMAINS[$((i-1))]}"
  SDIR="$STATE_BASE/$NAME"
  mkdir -p "$SDIR"

  if [[ -f "$SDIR/secret" ]]; then
    SECRET="$(cat "$SDIR/secret")"
  else
    SECRET="$(openssl rand -hex 16)"
    printf "%s" "$SECRET" > "$SDIR/secret"
  fi

  docker rm -f "$NAME" >/dev/null 2>&1 || true

  docker run -d --name "$NAME" --restart=always \
    -p ${PORT}:443 \
    -e SECRET="$SECRET" \
    -e TAG="$USE_TAG" \
    -e TLSPORT=443 \
    -e FAKE_TLS_DOMAIN="$DOMAIN" \
    -e NAT_PUBLIC_IP="$IPV4" \
    telegrammessenger/proxy:latest >/dev/null

  SERVER_LABEL="${HOSTNAME:-$IPV4}"
  LINK="https://t.me/proxy?server=${SERVER_LABEL}&port=${PORT}&secret=dd${SECRET}"

  LINKS_SIMPLE+=("$LINK")
  LINKS_GROUPED+=("FakeTLS: ${DOMAIN}\n${LINK}\n")
done

echo
echo "================= لیست 1 — فقط لینک‌ها (قابل کپی) ================="
for L in "${LINKS_SIMPLE[@]}"; do echo "$L"; done

echo
echo "================= لیست 2 — لینک‌ها به تفکیک FakeTLS ================"
for G in "${LINKS_GROUPED[@]}"; do echo -e "$G"; done

echo
echo "یادآوری:"
echo "- اگر Hostname داده‌ای، مطمئن شو A رکورد آن به ${IPV4} اشاره کند."
echo "- کانتینرها با --restart=always پس از ریبوت خودکار بالا می‌آیند."
