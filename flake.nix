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
    in {
      packages.${system}.dev-docker = pkgs.dockerTools.buildImage {
        name = "nix-dev-env";
        tag = "latest";
        fromImage = "docker://ubuntu:22.04";

        contents = with pkgs; [
          neovim
          tmux
          git
          wget
          curl
          openjdk
          nodejs
          fish
          typescript-language-server
        ];

        fakeRootCommands = ''
          ${pkgs.dockerTools.shadowSetup}
          useradd -m -s ${pkgs.fish}/bin/fish dev
        '';

        config = {
          User = "dev";
          Cmd = [ "${pkgs.fish}/bin/fish" "-l" ];
          Env = [ "HOME=/home/dev" ];
          WorkingDir = "/home/dev";
        };
      };
    };
}
