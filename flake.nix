{
  description = "MPFS Explorer — fact explorer and transaction verifier";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    purescript-overlay = {
      url = "github:thomashoneyman/purescript-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cardano-mpfs-offchain = {
      url = "github:lambdasistemi/cardano-mpfs-offchain";
    };
    cardano-mpfs-cage.follows = "cardano-mpfs-offchain/cardano-mpfs-cage";
    cardano-mpfs-onchain.follows = "cardano-mpfs-offchain/cardano-mpfs-onchain";
    cardano-node-clients.follows = "cardano-mpfs-offchain/cardano-node-clients";
    cardano-node.follows = "cardano-mpfs-offchain/cardano-node";
  };

  outputs = { self, nixpkgs, purescript-overlay, cardano-mpfs-offchain
    , cardano-mpfs-cage, cardano-mpfs-onchain, cardano-node-clients, cardano-node }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ purescript-overlay.overlays.default ];
          };
          devnet-server = cardano-mpfs-offchain.packages.${system}.mpfs-devnet-server or null;
          cardano-node-exe = cardano-node.packages.${system}.cardano-node or null;
        in {
          default = pkgs.mkShell {
            packages = [
              pkgs.purs
              pkgs.spago-unstable
              pkgs.purs-tidy-bin.purs-tidy-0_10_0
              pkgs.purescript-language-server
              pkgs.esbuild
              pkgs.nodejs_20
              pkgs.just
            ] ++ pkgs.lib.optional (devnet-server != null) devnet-server
              ++ pkgs.lib.optional (cardano-node-exe != null) cardano-node-exe;
          };
        });
      packages = forAllSystems (system: {
        cage-blueprint = cardano-mpfs-onchain.packages.${system}.default;
        cage-test-vectors = cardano-mpfs-cage.packages.${system}.cage-test-vectors;
        devnet-genesis = cardano-node-clients.packages.${system}.devnet-genesis;
      });
    };
}
