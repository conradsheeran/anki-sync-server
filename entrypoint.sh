#!/bin/sh
set -eu

DATA_DIR="${SYNC_BASE:-/data}"
ANKI_UID="$(id -u anki)"
ANKI_GID="$(id -g anki)"

if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
fi

current_uid="$(stat -c '%u' "$DATA_DIR")"
if [ "$current_uid" != "$ANKI_UID" ]; then
    echo "[entrypoint] chowning $DATA_DIR to anki ($ANKI_UID:$ANKI_GID)"
    chown -R "$ANKI_UID:$ANKI_GID" "$DATA_DIR"
fi

if [ -z "${SYNC_USER1:-}" ]; then
    echo "[entrypoint] ERROR: SYNC_USER1 is not set." >&2
    echo "[entrypoint] Set it to '<username>:<password>'." >&2
    exit 1
fi
case "$SYNC_USER1" in
    :*|*:)
        echo "[entrypoint] ERROR: SYNC_USER1='$SYNC_USER1' has empty user or password." >&2
        echo "[entrypoint] Check that ANKI_USER and ANKI_PASS are defined in your .env file." >&2
        exit 1
        ;;
    *:*) ;;
    *)
        echo "[entrypoint] ERROR: SYNC_USER1='$SYNC_USER1' missing ':' separator." >&2
        exit 1
        ;;
esac

echo "[entrypoint] SYNC env:"
env | grep -E '^SYNC_' | sed -E 's/(SYNC_USER[0-9]+=[^:]*:).*/\1***/' | sed 's/^/[entrypoint]   /'
echo "[entrypoint] data dir listing:"
ls -la "$DATA_DIR" | sed 's/^/[entrypoint]   /'
echo "[entrypoint] starting anki-sync-server on ${SYNC_HOST:-0.0.0.0}:${SYNC_PORT:-8080} base=$DATA_DIR"
exec gosu "$ANKI_UID:$ANKI_GID" "$@"
