{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  glibc,
  libcap,
  zlib,
  openssl,
}:
let
  currentVersion = (lib.importJSON ../version.json).acp;
  downloadUrl =
    platform:
    "https://github.com/zed-industries/codex-acp/releases/download/v${currentVersion.version}/codex-acp-${currentVersion.version}-${platform}-unknown-linux-gnu.tar.gz";
  defaultArgs =
    {
      "x86_64-linux" = {
        src = fetchurl {
          url = downloadUrl "x86_64";
          hash = currentVersion."hash-linux-x64";
        };
      };
      "aarch64-linux" = {
        src = fetchurl {
          url = downloadUrl "aarch64";
          hash = currentVersion."hash-linux-arm64";
        };
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "codex-acp: Unsupported platform: ${stdenv.hostPlatform.system}");
  runtimeLibraryPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    glibc
    libcap
    zlib
    openssl
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codex-acp";
  version = currentVersion.version;
  inherit (defaultArgs) src;

  nativeBuildInputs = [
    patchelf
  ];

  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;
  noDumpEnvVars = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    
    # The tarball should contain the binary
    if [ -f "codex-acp" ]; then
      cp codex-acp $out/lib/codex-acp-bin
    else
      BINARY=$(find . -maxdepth 2 -name codex-acp -type f | head -n 1)
      if [ -n "$BINARY" ]; then
        cp "$BINARY" $out/lib/codex-acp-bin
      else
        echo "Error: codex-acp binary not found"
        exit 1
      fi
    fi

    # Patch the binary
    patchelf \
      --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
      --set-rpath "${runtimeLibraryPath}" \
      $out/lib/codex-acp-bin

    # Wrap the binary
    {
      printf '%s\n' "#!${stdenv.shell}"
      printf '%s\n' "exec \"$out/lib/codex-acp-bin\" \"\$@\""
    } > $out/bin/codex-acp
    chmod 755 $out/bin/codex-acp

    runHook postInstall
  '';

  meta = {
    description = "Codex Autocompletion Provider";
    homepage = "https://github.com/zed-industries/codex-acp";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = "codex-acp";
  };
})
