{
  description = "search-algorithms-monoid";

  inputs = {
    haskell-nix.url = "github:mlabs-haskell/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    fourmolu = {
      url = "github:fourmolu/fourmolu?ref=v0.6.0.0";
      flake = false;
    };
    hlint = {
      url = "github:ndmitchell/hlint?ref=v3.4";
      flake = false;
    };
    haskell-language-server.url = "github:haskell/haskell-language-server";
  };

  outputs = { self, nixpkgs, haskell-nix, fourmolu, hlint, haskell-language-server, ... }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      perSystem = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ haskell-nix.overlay ];
        inherit (haskell-nix) config;
      };

      fourmoluFor = system: (((nixpkgsFor system).haskell-nix.cabalProject' {
        compiler-nix-name = "ghc921";
        src = "${fourmolu}";
      }).getPackage "fourmolu").components.exes.fourmolu;

      hlintFor = system: (((nixpkgsFor system).haskell-nix.cabalProject' {
        compiler-nix-name = "ghc921";
        src = "${hlint}";
      }).getPackage "hlint").components.exes.hlint;

      projectFor = system:
        let
          pkgs = nixpkgsFor system;
        in
        pkgs.haskell-nix.cabalProject' {
          name = "search-algorithms-monoid";
          compiler-nix-name = "ghc922";
          src = ./.;
          modules = [{
            reinstallableLibGhc = true;
          }];

          shell = {
            withHoogle = true;
            exactDeps = true;

            nativeBuildInputs = [
              pkgs.cabal-install
              pkgs.nixpkgs-fmt
              pkgs.haskellPackages.cabal-fmt
              pkgs.haskellPackages.apply-refact
              pkgs.haskellPackages.hspec-discover
              haskell-language-server.packages.${system}.haskell-language-server-922
              (fourmoluFor system)
              (hlintFor system)
            ];
          };
        };
    in
    {
      inherit nixpkgsFor;

      project = perSystem projectFor;
      flake = perSystem (system: (projectFor system).flake { });

      packages = perSystem (system: self.flake.${system}.packages);
      apps = perSystem (system: self.flake.${system}.apps);
      devShell = perSystem (system: self.flake.${system}.devShell);
    };
}
