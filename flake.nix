{
  description = "Cross-platform user packages for my DEV enviroment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:

      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        commonPackages = with pkgs; [
          neovim
          ghostty-bin
          tmux
          git
          ripgrep
          fd
          fzf
          fish
        ];

        linuxOnly = with pkgs; [
          xclip
        ];

        darwinOnly = with pkgs; [
          karabiner-elements
          # mac-specific tools if needed
        ];

        packages =
          commonPackages
          ++ lib.optionals pkgs.stdenv.isLinux linuxOnly
          ++ lib.optionals pkgs.stdenv.isDarwin darwinOnly;

      in {
        packages.default = pkgs.buildEnv {
          name = "user-packages";
          paths = packages;
        };
      });
}
