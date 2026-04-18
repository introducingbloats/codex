{
  lib,
  writeShellApplication,
  jq,
  coreutils,
  curl,
  nix,
}:
writeShellApplication {
  name = "codex-update";
  runtimeInputs = [
    jq
    coreutils
    curl
    nix
  ];
  text = ''
    set -euo pipefail

    VERSION_FILE="version.json"

    update_cli() {
      echo "Fetching latest release from openai/codex"
      RELEASE=$(curl -sL "https://api.github.com/repos/openai/codex/releases/latest")
      VERSION=$(echo "$RELEASE" | jq -r '.tag_name' | sed 's/^rust-v//')
      echo "Latest codex-cli version: $VERSION"

      CURRENT_VERSION=$(jq -r '.cli.version' "$VERSION_FILE")
      if [ "$VERSION" = "$CURRENT_VERSION" ]; then
        echo "codex-cli is already up-to-date ($VERSION), skipping."
        return 0
      fi

      echo "Fetching x86_64-linux tarball hash"
      X64_URL="https://github.com/openai/codex/releases/download/rust-v$VERSION/codex-x86_64-unknown-linux-gnu.tar.gz"
      X64_HASH=$(nix store prefetch-file --json "$X64_URL" | jq -r '.hash')
      
      echo "Fetching aarch64-linux tarball hash"
      ARM64_URL="https://github.com/openai/codex/releases/download/rust-v$VERSION/codex-aarch64-unknown-linux-gnu.tar.gz"
      ARM64_HASH=$(nix store prefetch-file --json "$ARM64_URL" | jq -r '.hash')

      jq --arg version "$VERSION" \
         --arg hash_x64 "$X64_HASH" \
         --arg hash_arm64 "$ARM64_HASH" \
         '.cli.version = $version | .cli."hash-linux-x64" = $hash_x64 | .cli."hash-linux-arm64" = $hash_arm64' \
         "$VERSION_FILE" > "$VERSION_FILE.tmp" && mv "$VERSION_FILE.tmp" "$VERSION_FILE"
    }

    update_acp() {
      echo "Fetching latest release from zed-industries/codex-acp"
      RELEASE=$(curl -sL "https://api.github.com/repos/zed-industries/codex-acp/releases/latest")
      VERSION=$(echo "$RELEASE" | jq -r '.tag_name' | sed 's/^v//')
      echo "Latest codex-acp version: $VERSION"

      CURRENT_VERSION=$(jq -r '.acp.version' "$VERSION_FILE")
      if [ "$VERSION" = "$CURRENT_VERSION" ]; then
        echo "codex-acp is already up-to-date ($VERSION), skipping."
        return 0
      fi

      echo "Fetching x86_64-linux tarball hash"
      X64_URL="https://github.com/zed-industries/codex-acp/releases/download/v$VERSION/codex-acp-$VERSION-x86_64-unknown-linux-gnu.tar.gz"
      X64_HASH=$(nix store prefetch-file --json "$X64_URL" | jq -r '.hash')
      
      echo "Fetching aarch64-linux tarball hash"
      ARM64_URL="https://github.com/zed-industries/codex-acp/releases/download/v$VERSION/codex-acp-$VERSION-aarch64-unknown-linux-gnu.tar.gz"
      ARM64_HASH=$(nix store prefetch-file --json "$ARM64_URL" | jq -r '.hash')

      jq --arg version "$VERSION" \
         --arg hash_x64 "$X64_HASH" \
         --arg hash_arm64 "$ARM64_HASH" \
         '.acp.version = $version | .acp."hash-linux-x64" = $hash_x64 | .acp."hash-linux-arm64" = $hash_arm64' \
         "$VERSION_FILE" > "$VERSION_FILE.tmp" && mv "$VERSION_FILE.tmp" "$VERSION_FILE"
    }

    if [ "$#" -eq 0 ]; then
      update_cli
      update_acp
    else
      for arg in "$@"; do
        case "$arg" in
          cli) update_cli ;;
          acp) update_acp ;;
          *) echo "Unknown component: $arg"; exit 1 ;;
        esac
      done
    fi

    echo "Successfully updated $VERSION_FILE"
  '';
}
