# Joy (non-keyed)

[Joy](https://github.com/niclas-ahden/joy) implementation of the js-framework-benchmark
table app. percy diffs children by position, so this is a non-keyed entry.

Joy's repo drives this entry via its `benchmarks/jsframework/run.sh`, but everything
below works standalone too.

## Prerequisites

Enter this repo's dev shell for the full toolchain (node/npm plus roc/zig/wasm-pack/cargo):

```sh
direnv allow      # or: nix develop
```

The build expects a `joy` checkout next to this repo. Override with
`JOY_ROOT=/path/to/joy` if yours lives elsewhere.

## Build

```sh
npm run build-prod    # roc -> wasm object -> zig static lib -> wasm-pack, into ./dist
```

The runner loads the result via `"customURL": "/dist"` in `package.json`.

## Run

From the repo root, with the runner installed (`npm run install-local`):

```sh
npm start                                              # serve the repo (separate terminal)
npm run bench -- --framework non-keyed/joy non-keyed/vanillajs keyed/elm
npm run results
```

Verify the keyed/non-keyed classification:

```sh
cd webdriver-ts && npm run isKeyed non-keyed/joy
```

## Smoke test without the npm runner

`validate.roc` drives the built app with roc-playwright and asserts the same DOM facts
the runner checks. Serve `dist/` at `/jsfw/index.html` with any static server, then:

```sh
BENCH_URL=http://localhost:8081 roc dev validate.roc --linker=legacy
```
