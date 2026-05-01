{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  patchelf,
  glibc,
  libcap,
  zlib,
  openssl,
}:
let
  currentVersion = (lib.importJSON ../version.json).cli;
  downloadUrl =
    platform:
    "https://github.com/openai/codex/releases/download/rust-v${currentVersion.version}/codex-${platform}-unknown-linux-musl.tar.gz";
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
      or (throw "codex-cli: Unsupported platform: ${stdenv.hostPlatform.system}");
  runtimeLibraryPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    glibc
    libcap
    zlib
    openssl
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codex-cli";
  version = currentVersion.version;
  inherit (defaultArgs) src;

  nativeBuildInputs = [
    installShellFiles
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
    
    # Install files from the tarball
    cp -r * $out/lib/
    
    # The actual binary in the tarball has a platform suffix like codex-x86_64-unknown-linux-musl
    BINARY=$(find . -maxdepth 2 -type f -name "codex*" | head -n 1)
    if [ -n "$BINARY" ]; then
      mv $out/lib/$(basename "$BINARY") $out/lib/codex-bin
    else
       echo "Error: codex binary not found"
       exit 1
    fi

    # Patch the binary
    patchelf \
      --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
      --set-rpath "${runtimeLibraryPath}" \
      $out/lib/codex-bin

    # Wrap the binary in a shell script
    {
      printf '%s\n' "#!${stdenv.shell}"
      printf '%s\n' "exec \"$out/lib/codex-bin\" \"\$@\""
    } > $out/bin/codex
    chmod 755 $out/bin/codex

    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = "codex";
  };
})
