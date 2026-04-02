{
  description = "Docker Dev Environment with Chezmoi Subfolder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix2container.url = "github:nlewo/nix2container";
    
    dotfiles = {
      url = "github:andikon/dotfiles";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nix2container, dotfiles }:
    let
      system = "x86_64-linux"; 
      pkgs = import nixpkgs { inherit system; };
      n2c = nix2container.packages.${system}.nix2container;

      # Define these as basic types (string/int) explicitly
      user = "dev";
      uid = 1000;
      gid = 1000;

      containerPkgs = with pkgs; [
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

      userHome = pkgs.runCommand "user-home" { } ''
        # Create destination
        mkdir -p $out/home/${user}/.local/share/chezmoi
        
        # Copy the 'dotfiles' subfolder from your repo
        cp -r ${dotfiles}/dotfiles/. $out/home/${user}/.local/share/chezmoi/
        
        # Apply dotfiles at build time using a temporary HOME
        export HOME=$(mktemp -d)
        ${pkgs.chezmoi}/bin/chezmoi apply \
          --destination $out/home/${user} \
          --source $out/home/${user}/.local/share/chezmoi \
          --no-pager \
          --force || true
        
        # Create user/group files
        mkdir -p $out/etc
        echo "${user}:x:${toString uid}:${toString gid}::/home/${user}:${pkgs.fish}/bin/fish" > $out/etc/passwd
        echo "${user}:x:${toString gid}:" > $out/etc/group

        # Sudoers
        mkdir -p $out/etc/sudoers.d
        echo "${user} ALL=(ALL) NOPASSWD: ALL" > $out/etc/sudoers.d/${user}
      '';

      # Define the image here to avoid recursive 'self' issues
      devImage = n2c.buildImage {
        name = "andrijkoenig/nix-dev-env";
        tag = "latest";

        copyToRoot = [
          (pkgs.buildEnv {
            name = "root-env";
            paths = containerPkgs;
            pathsToLink = [ "/bin" "/etc" ];
          })
          userHome
        ];

        perms = [
          {
            path = userHome;
            regex = "/home/${user}";
            mode = "0755";
            uid = uid;
            gid = gid;
          }
          {
            path = userHome;
            regex = "/etc/sudoers.d/${user}";
            mode = "0440";
            uid = 0;
            gid = 0;
          }
        ];

        config = {
          Cmd = [ "${pkgs.fish}/bin/fish" ];
          User = "${user}";
          WorkingDir = "/home/${user}";
          Env = [
            "HOME=/home/${user}"
            "USER=${user}"
            "TERM=xterm-256color"
            "SHELL=${pkgs.fish}/bin/fish"
          ];
        };
      };

    in {
      # Now map the defined image to the output attributes
      packages.${system} = {
        devContainer = devImage;
        default = devImage;
      };
    };
}