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

        userPackages = pkgs.buildEnv {
          name = "user-packages";
          paths = packagesList;
        };

      in
      {
        # normal package output
        packages.default = userPackages;

        # ✅ Docker image must live under packages.*
        packages.devContainer =
          if pkgs.stdenv.isLinux then
            pkgs.dockerTools.buildImage {
			  name = "dev-env-${builtins.substring 0 8 imageRoot.drvHash}";
			  tag = "latest";

			  copyToRoot = pkgs.buildEnv {
				name = "image-root";
				paths = [
				  userPackages
				  pkgs.bash
				  pkgs.fish
				];
			  };

			  extraCommands = ''
				mkdir -p $out/root/.config/nvim
				mkdir -p $out/root/.config/fish

				cp -r ${dotfiles}/nvim $out/root/.config/nvim || true
				cp -r ${dotfiles}/fish $out/root/.config/fish || true
				cp ${dotfiles}/.tmux.conf $out/root/.tmux.conf || true
				cp ${dotfiles}/git/.gitconfig $out/root/.gitconfig || true
				cp -r ${dotfiles}/scripts $out/root/scripts || true
			  '';

			  config = {
				Cmd = [ "fish" ];
				Env = [ "SHELL=/bin/fish" ];
			  };
			}
          else
            throw "devContainer only supported on Linux";
      });
}