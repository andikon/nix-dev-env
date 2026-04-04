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
	  
	  fakeNssDev =
		  pkgs.dockerTools.fakeNss.override {
			extraPasswdLines = [
			  "dev:x:1000:1000:Dev User:/home/dev:${pkgs.fish}/bin/fish"
			];

			extraGroupLines = [
			  "dev:x:1000:"
			];
		  };
    in {
      packages.${system}.dev-docker = pkgs.dockerTools.buildLayeredImage  {
        name = "nix-dev-env";
        tag = "latest";
		
		contents = [
		  home
		  fakeNssDev
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
          # create home directory
          # mkdir -p home/dev

          # install home-manager result
          # cp -r ${home}/home-files/. home/dev/

          # ownership by numeric uid/gid
          # chown -R 1000:1000 home/dev

          # fish expects /bin/sh
          # mkdir -p bin
          # ln -s ${pkgs.bash}/bin/bash bin/sh
        '';

        config = {
          User = "1000:1000";
          Cmd = [ "${pkgs.fish}/bin/fish" "-l" ];
          Env = [ "HOME=/home/dev" "USER=dev" ];
          WorkingDir = "/home/dev";
        };
      };
    };
}
