{
  description = "Cross-platform user packages for my DEV enviroment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    dotfiles = {
	  url = "github:andikon/dotfiles";
	  flake = false;
	};
  };

  outputs = { self, nixpkgs, flake-utils, dotfiles }:
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

        # devContainer: linux-only OCI image built with Nix's dockerTools
        devContainer = lib.optionalAttrs pkgs.stdenv.isLinux (pkgs.dockerTools.buildImage {
          name = "dev-env";
          tag = "dev-env:latest";

          # Include the user-packages buildEnv so tools are available in the image
          contents = [ (pkgs.buildEnv { name = "user-packages"; paths = packages; }) pkgs.bash pkgs.fish ];

          # Copy selected linux dotfiles from a `dotfiles` directory in the repo (add as submodule if needed)
          extraCommands = ''
            mkdir -p $out/root/.config/nvim
            mkdir -p $out/root/.config/fish
            # Copy files from the dotfiles flake input (declarative, pinned via flake input)
            cp -r ${toString dotfiles}/nvim $out/root/.config/nvim || true
            cp -r ${toString dotfiles}/fish $out/root/.config/fish || true
            cp ${toString dotfiles}/.tmux.conf $out/root/.tmux.conf || true
            cp ${toString dotfiles}/git/.gitconfig $out/root/.gitconfig || true
            cp -r ${toString dotfiles}/scripts $out/root/scripts || true
          '';

          config = {
            Cmd = ["fish"];
            Env = [ "SHELL=/bin/fish" ];
          };
        });
      });
}
