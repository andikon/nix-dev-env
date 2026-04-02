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

        # Add basic utilities and dotfiles for the image
        imageRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [
            userEnv
            pkgs.bash
            pkgs.fish
            pkgs.coreutils    # mkdir, rm, cp, etc
            pkgs.util-linux   # uname
            pkgs.findutils    # find
            pkgs.gnugrep      # grep
            pkgs.gnused       # sed
            pkgs.gawk         # awk
          ] ++ [ dotfiles ];  # copy dotfiles into /nix/store/imageRoot/dotfiles
        };

        # Wrap dotfiles copy to /root inside container
        imageRootWithDotfiles = pkgs.runCommand "dotfiles-root" { } ''
          mkdir -p $out/root
          cp -r ${dotfiles}/* $out/root/
          # Merge with previous imageRoot
          cp -r ${imageRoot}/* $out/
        '';

        # ------------------------
        # nix2container image
        # ------------------------

        devContainer =
          n2c.buildImage {
            name = "docker.io/andrijkoenig/nix-dev-env";
            tag = "latest";

            # Use the combined root FS
            copyToRoot = imageRootWithDotfiles;

            config = {
              Cmd = [ "${pkgs.fish}/bin/fish" ];
              Env = [ "SHELL=${pkgs.fish}/bin/fish" ];
              WorkingDir = "/root";
            };
          };

      in
      {
        packages = lib.optionalAttrs pkgs.stdenv.isLinux {
          default = userEnv;
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