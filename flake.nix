{
  outputs =
    {
      self,
      ...
    }@inputs:
    let
      lib-nixpkgs = inputs.introducingbloats.lib.nixpkgs inputs;
    in
    {
      packages = lib-nixpkgs.forSystems lib-nixpkgs.linuxOnly (
        { pkgs, ... }:
        let
          cli = pkgs.callPackage ./cli/package.nix { };
          acp = pkgs.callPackage ./acp/package.nix { };
        in
        {
          codex-cli = cli;
          codex-acp = acp;
          all = pkgs.symlinkJoin {
            name = "codex-all";
            paths = [ cli acp ];
          };
          default = cli;
          updateScript = pkgs.callPackage ./update.nix { };
        }
      );
    };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05-small";
    introducingbloats.url = "github:introducingbloats/core.flakes/main";
  };
}
