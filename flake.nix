{
  description = "A very basic flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
        {

          devShells.default = import ./shell.nix { inherit pkgs; };

          devShells.jekyll = with pkgs; let
            env = bundlerEnv {
              name = "your-package";
              inherit ruby;
              gemfile = ./Gemfile;
              lockfile = ./Gemfile.lock;
              gemset = ./gemset.nix;
            };
          in
            stdenv.mkDerivation {
              name = "jekyll-env";
              buildInputs = [env bundler ruby];
            };
        }
    );
}
