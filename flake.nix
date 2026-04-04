{
  description = "dev docker image with dotfiles (built with nix)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    dotfiles.url = "github:andikon/dotfiles";
  };

  outputs = { self, nixpkgs, dotfiles, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
	  
	  home = dotfiles.homeConfigurations."dev@docker".activationPackage;
    in {
      packages.${system}.dev-docker = pkgs.dockerTools.buildLayeredImage  {
        name = "nix-dev-env";
        tag = "latest";
		
		contents = [
		  home
		] ++ (with pkgs; [
		  coreutils  
		  busybox
		  bash        
		  gnugrep
		  gnused
          neovim
          tmux
          git
          wget
          curl
          openjdk
          nodejs
          fish
          typescript-language-server
        ]);

        extraCommands = ''
		  mkdir -p home/dev
		  chown -R 1000:1000 home/dev
		'';

        config = {
          User = "1000:1000";
          Cmd = [ "${pkgs.fish}/bin/fish" "-l" ];
          Env = [ "HOME=/home/dev" ];
          WorkingDir = "/home/dev";
        };
      };
    };
}
