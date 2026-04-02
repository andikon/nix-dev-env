{
  description = "Cross-platform dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix2container.url = "github:nlewo/nix2container";

    dotfiles = {
      url = "github:andikon/dotfiles";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, nix2container, dotfiles }:
    flake-utils.lib.eachDefaultSystem (system:

      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;
        n2c = nix2container.packages.${system}.nix2container;

        # ------------------------
        # Packages
        # ------------------------

        commonPackages = with pkgs; [
          neovim
          tmux
          git
          ripgrep
          fd
          fzf
          fish
        ];

        linuxOnly = with pkgs; [
          xclip
          ghostty
        ];

        darwinOnly = with pkgs; [
          karabiner-elements
          ghostty-bin
        ];

        packagesList =
          commonPackages
          ++ lib.optionals pkgs.stdenv.isLinux linuxOnly
          ++ lib.optionals pkgs.stdenv.isDarwin darwinOnly;

        # user environment
        userEnv = pkgs.buildEnv {
          name = "user-env";
          paths = packagesList;
        };

        # ------------------------
        # Container root FS
        # ------------------------

        imageRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [
            userEnv
            pkgs.bash
            pkgs.fish
          ];
        };

        # ------------------------
        # nix2container image
        # ------------------------

        devContainer =
          n2c.buildImage {
            name = "dev-env-${system}";
            tag = "latest";

            copyToRoot = imageRoot;

            config = {
              Cmd = [ "${pkgs.fish}/bin/fish" ];
              Env = [ "SHELL=${pkgs.fish}/bin/fish" ];
              WorkingDir = "/root";
            };
          };

      in
      {
        packages =
          {
            default = userEnv;
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            devContainer = devContainer;
          };

        devShells.default = pkgs.mkShell {
          packages = packagesList;
          shellHook = ''
            exec ${pkgs.fish}/bin/fish
          '';
        };
      });
}