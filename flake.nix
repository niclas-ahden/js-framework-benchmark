{
  description = "js-framework-benchmark dev shell (with Joy's Roc/wasm toolchain)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Pin the Roc compiler to the exact rev Joy's platform is built against
    # (matches crates/roc's roc_std pin in ../joy). Building the Joy benchmark entry
    # with a different roc would risk ABI mismatches.
    roc.url = "github:roc-lang/roc/4c206185a278f3adf7a23e8336cc94cd849b358f";
  };

  outputs = { nixpkgs, flake-utils, roc, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rocCli = roc.packages.${system}.full;

        # Match the wasm toolchain Joy is known to build with: wasm-bindgen 0.2.108
        # (as resolved in ../joy/Cargo.lock) and a recent wasm-pack. Versions/hashes
        # mirror the broc7 dev shell, which builds the same crates/web successfully.
        wasm-pack-0_14 = pkgs.wasm-pack.overrideAttrs (oldAttrs: rec {
          version = "0.14.0";
          src = pkgs.fetchFromGitHub {
            owner = "rustwasm";
            repo = "wasm-pack";
            rev = "v${version}";
            hash = "sha256-ik6AJUKuT3GCDTZbHWcplcB7cS0CIcZwFNa6SvGzsIQ=";
          };
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit src;
            name = "${oldAttrs.pname}-${version}";
            hash = "sha256-n9xuwlj8+3fDTHMS2XobqWFc6mNHQcmmvebRDc82oSo=";
          };
        });

        wasm-bindgen-cli-0_2_108 = pkgs.wasm-bindgen-cli.overrideAttrs (oldAttrs: rec {
          version = "0.2.108";
          src = pkgs.fetchCrate {
            pname = "wasm-bindgen-cli";
            inherit version;
            hash = "sha256-UsuxILm1G6PkmVw0I/JF12CRltAfCJQFOaT4hFwvR8E=";
          };
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit src;
            name = "${oldAttrs.pname}-${version}";
            hash = "sha256-iqQiWbsKlLBiJFeqIYiXo3cqxGLSjNM8SOWXGM9u43E=";
          };
        });
      in
      {
        formatter = pkgs.nixpkgs-fmt;

        devShells.default = pkgs.mkShell {
          buildInputs = [
            # Benchmark runner toolchain
            pkgs.nodejs_22 # provides node + npm + npx for the official runner
            pkgs.jq
            pkgs.git

            # For comparison entries built from source:
            #   Elm (keyed/elm) -- the npm `elm` package ships a binary that won't run
            #   on NixOS, so provide the compiler via nix instead.
            pkgs.elmPackages.elm

            # Joy benchmark entry build (roc -> zig -> wasm-pack)
            rocCli
            pkgs.zig
            pkgs.cargo
            pkgs.rustc
            pkgs.lld
            wasm-pack-0_14
            wasm-bindgen-cli-0_2_108
          ] ++ pkgs.lib.optionals (!pkgs.stdenv.isDarwin) [
            pkgs.inotify-tools
          ];

          shellHook = ''
            # Use the nix-provided browsers for Playwright (the npm-downloaded ones don't
            # run on NixOS). NOTE: this nixpkgs ships playwright-driver 1.59.1 while
            # webdriver-ts pins playwright 1.58.2; the npm side must be aligned to 1.59.1
            # (bump webdriver-ts's playwright deps) for the browsers here to be found.
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

            export ROC_LANGUAGE_SERVER_PATH=${rocCli}/bin/roc_language_server
            export ZIG_GLOBAL_CACHE_DIR=$HOME/.zig-cache
          '';
        };
      });
}
