#!/usr/bin/env bash
# Build the Joy benchmark app into ./dist (index.html + pkg/ wasm bundle), which the
# js-framework-benchmark runner loads via the package.json "customURL": "/dist".
#
# Joy's platform is a Rust crate (crates/web) that links the compiled Roc app, so the
# pipeline is: roc -> wasm object -> zig static lib -> wasm-pack. The instrumentation
# `joy_bench` feature is intentionally NOT enabled, so the benchmark measures a clean
# release build.
#
# JOY_ROOT defaults to a sibling `joy` checkout; override it if yours lives elsewhere:
#   JOY_ROOT=/path/to/joy npm run build-prod
set -eo pipefail

cd "$(dirname "$0")"
here=$(pwd)
JOY="${JOY_ROOT:-$here/../../../../joy}"

if [ ! -f "$JOY/platform/main.roc" ]; then
    echo "ERROR: Joy platform not found at $JOY/platform/main.roc" >&2
    echo "Set JOY_ROOT to your joy checkout." >&2
    exit 1
fi
JOY=$(cd "$JOY" && pwd)   # normalize to absolute

dist="$here/dist"
rm -rf "$dist"
mkdir -p "$dist"
rm -f "$JOY/app.o" "$JOY/libapp.a"

# Roc app -> wasm object. Exit code 2 is "compiled with warnings", which is fine.
exit_code=0
roc build --target wasm32 --no-link --emit-llvm-ir --output "$JOY/app.o" "$here/main.roc" || exit_code=$?
if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    exit "$exit_code"
fi

# wasm object -> static lib that crates/web links against (read from JOY_PROJECT_ROOT).
( cd "$JOY" && zig build-lib -target wasm32-freestanding-musl --library c app.o )

# Optimized wasm bundle (no joy_bench instrumentation).
( cd "$JOY/crates/web" \
    && JOY_PROJECT_ROOT="$JOY" wasm-pack build --release --target web --out-dir "$dist/pkg" )

cp "$here/index.html" "$dist/index.html"
rm -f "$JOY/app.o" "$JOY/libapp.a"

echo "Built Joy benchmark into $dist"
