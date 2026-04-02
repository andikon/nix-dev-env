{
  description = "Custom Development Environment Docker Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Fetch your dotfiles directly via flake inputs
    dotfiles = {
      url = "github:andikon/dotfiles";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, dotfiles }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # User definitions
      user = "dev";
      uid = "1000";
      gid = "1000";
      home = "/home/${user}";

      # Pre-bake the home directory by running chezmoi during the Nix build
      bakedHome = pkgs.stdenv.mkDerivation {
        name = "dev-home";
        src = dotfiles;
        nativeBuildInputs = [ pkgs.chezmoi pkgs.git ];
        
        buildPhase = ''
          # Create a temporary home directory for the build
          export HOME=$PWD/home
          export USER=${user}
          mkdir -p $HOME

          # Apply chezmoi using the nested 'dotfiles' folder from your repo
          chezmoi --source $src/dotfiles apply
        '';
        
        installPhase = ''
          mkdir -p $out
          # Copy everything, including hidden files, to the output
          cp -rT $HOME $out
        '';
      };

    in
    {
      packages.${system}.default = pkgs.dockerTools.buildLayeredImage {
        name = "nix-dev-env";
        tag = "latest";
        created = "now"; # Ensures the image has a timestamp, overriding the 1970 Nix epoch

        contents = with pkgs; [
          bashInteractive
          fish
          git
          neovim
          tmux
          ripgrep
          fd
          fzf
          sudo
          coreutils
          shadow
          chezmoi
        ];

        # fakeRootCommands allows us to manipulate the file system as 'root' 
        # before the final image layers are squashed.
        fakeRootCommands = ''
          # Set up standard directories
          mkdir -p tmp
          chmod 1777 tmp

          # Link common shell and env paths heavily relied upon by scripts
          mkdir -p usr/bin bin
          ln -s ${pkgs.coreutils}/bin/env usr/bin/env
          ln -s ${pkgs.bashInteractive}/bin/bash bin/sh

          # Set up /etc/passwd, /etc/group, /etc/shadow manually
          mkdir -p etc
          echo "root:x:0:0:root:/root:${pkgs.bashInteractive}/bin/bash" > etc/passwd
          echo "${user}:x:${uid}:${gid}:Dev User:${home}:${pkgs.fish}/bin/fish" >> etc/passwd

          echo "root:x:0:" > etc/group
          echo "${user}:x:${gid}:" >> etc/group

          echo "root:!x:::::::" > etc/shadow
          echo "${user}:!x:::::::" >> etc/shadow

          # Configure passwordless sudo for the dev user
          mkdir -p etc/sudoers.d
          echo "${user} ALL=(ALL) NOPASSWD: ALL" > etc/sudoers.d/${user}
          chmod 0440 etc/sudoers.d/${user}

          # Inject the baked home directory and fix ownership
          mkdir -p ${home}
          cp -rT ${bakedHome} ${home}
          chown -R ${uid}:${gid} ${home}
        '';

        config = {
          Cmd = [ "${pkgs.fish}/bin/fish" ];
          User = user;
          Env = [
            "USER=${user}"
            "HOME=${home}"
            "TERM=xterm-256color"
          ];
          WorkingDir = home;
        };
      };
    };
}