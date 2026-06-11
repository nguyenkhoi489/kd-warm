#!/usr/bin/env bash
# S3 (nginx slice) — builds a relocatable nginx (TLS-capable) and proves it runs from a
# MOVED dir. Relocatability technique = static-link OpenSSL + PCRE2 (so no Homebrew Cellar
# dylib paths leak in), let zlib resolve to the always-present system /usr/lib/libz.
#
# Static-link trick: point -L at a dir containing ONLY the .a archives (no .dylib), so the
# linker is forced to pick the static libs for -lssl/-lcrypto/-lpcre2-8.
#
# nginx bakes its prefix at compile time; the real relocatability concern is whether it runs
# from a different location — proven by launching from the MOVED dir with a runtime `-p` override.
set -euo pipefail
cd "$(dirname "$0")"

NGX_VER="${NGX_VER:-1.27.4}"
SSL_PREFIX="$(brew --prefix openssl@3)"
PCRE_PREFIX="$(brew --prefix pcre2)"
STAGE="$PWD/staging-nginx"
MOVED="$PWD/staging-nginx-MOVED"
SRC="$STAGE/src/nginx-${NGX_VER}"
PREFIX="$STAGE/nginx"
STATICLIBS="$STAGE/staticlibs"

rm -rf "$STAGE" "$MOVED"
mkdir -p "$STAGE/src" "$STATICLIBS"

echo "=== isolate static archives (force static link) ==="
ln -sf "$SSL_PREFIX/lib/libssl.a"        "$STATICLIBS/libssl.a"
ln -sf "$SSL_PREFIX/lib/libcrypto.a"     "$STATICLIBS/libcrypto.a"
ln -sf "$PCRE_PREFIX/lib/libpcre2-8.a"   "$STATICLIBS/libpcre2-8.a"

echo "=== download nginx ${NGX_VER} source ==="
curl -fsSL "https://nginx.org/download/nginx-${NGX_VER}.tar.gz" -o "$STAGE/src/nginx.tar.gz"
tar -xzf "$STAGE/src/nginx.tar.gz" -C "$STAGE/src"

echo "=== configure (static ssl/pcre2, system zlib) ==="
cd "$SRC"
./configure \
    --prefix="$PREFIX" \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-cc-opt="-I$SSL_PREFIX/include -I$PCRE_PREFIX/include" \
    --with-ld-opt="-L$STATICLIBS" >/dev/null
echo "=== make ==="
make -j"$(sysctl -n hw.ncpu)" >/dev/null
make install >/dev/null
NGINX="$PREFIX/sbin/nginx"
cd "$(dirname "$0")"

echo "=== otool -L (relocatability signal) ==="
otool -L "$NGINX"
BAD=$(otool -L "$NGINX" | tail -n +2 | awk '{print $1}' \
        | grep -vE '^(/usr/lib/|/System/|@rpath/|@executable_path/|@loader_path/)' || true)
[[ -z "$BAD" ]] && echo "  ✓ no fragile (Homebrew/Cellar) dylib refs" || { echo "  ✗ leaked refs:"; echo "$BAD" | sed 's/^/    /'; }

echo "=== health probe IN PLACE ==="
"$NGINX" -V 2>&1 | head -1

echo "=== MOVE dir, run nginx from moved path with -p override, serve + curl ==="
mv "$STAGE" "$MOVED"
MNGINX="$MOVED/nginx/sbin/nginx"
MPREFIX="$MOVED/nginx"
# minimal runtime conf on a high port (no privileged bind / no root needed)
mkdir -p "$MPREFIX/conf" "$MPREFIX/logs" "$MPREFIX/html"
cat > "$MPREFIX/conf/spike.conf" <<CONF
worker_processes 1;
error_log $MPREFIX/logs/error.log;
pid $MPREFIX/logs/nginx.pid;
events {}
http {
    access_log off;
    server { listen 127.0.0.1:8088; location / { return 200 "nginx relocated ok\n"; } }
}
CONF
"$MNGINX" -p "$MPREFIX" -c "$MPREFIX/conf/spike.conf"
for _ in $(seq 1 50); do lsof -nP -iTCP:8088 -sTCP:LISTEN >/dev/null 2>&1 && break; done
BODY=$(curl -fsS http://127.0.0.1:8088/ 2>&1 || true)
echo "  curl => $BODY"
"$MNGINX" -p "$MPREFIX" -c "$MPREFIX/conf/spike.conf" -s stop 2>/dev/null || pkill -f "$MNGINX" 2>/dev/null || true

# --- gate ---
if [[ -z "$BAD" && "$BODY" == "nginx relocated ok" ]]; then
    echo "S3-NGINX PASS — TLS-capable nginx ${NGX_VER} runs + serves from a moved dir; otool clean."
    exit 0
else
    echo "S3-NGINX FAIL — BAD='$BAD' body='$BODY'"
    exit 1
fi
