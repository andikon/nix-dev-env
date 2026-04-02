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
    chezmoi = {
      url = "github:twpayne/chezmoi";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, nix2container, dotfiles, chezmoi }:
    flake-utils.lib.eachDefaultSystem (system:

      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;
        n2c = nix2container.packages.${system}.nix2container;

        # ------------------------
        # Packages
        # ------------------------

        commonPackages = with pkgs; [
          chezmoi
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
            pkgs.sudo         # Add sudo for privilege escalation
            pkgs.shadow       # user/group tools if needed
            pkgs.coreutils    # mkdir, rm, cp, etc
            pkgs.util-linux   # uname
            pkgs.findutils    # find
            pkgs.gnugrep      # grep
            pkgs.gnused       # sed
            pkgs.gawk         # awk
          ];
        };

        # Use chezmoi to apply dotfiles in container
        imageRootWithDotfiles = pkgs.runCommand "dotfiles-root" { } ''
          mkdir -p $out/home/dev
          
          # Copy base environment
          cp -r ${imageRoot}/* $out/
          
          # Copy dotfiles source for dev user
          mkdir -p $out/home/dev/.local/share/chezmoi
          cp -r ${dotfiles}/dotfiles/* $out/home/dev/.local/share/chezmoi/
          
          # Initialize chezmoi and apply
          export HOME=$out/home/dev
          mkdir -p $HOME/.config/chezmoi
          ${pkgs.chezmoi}/bin/chezmoi --source=$HOME/.local/share/chezmoi init --apply --no-pager 2>/dev/null || true
          
          # Set proper permissions
          chown -R 1000:1000 $out/home/dev
        '';

        # Create sudoers file for passwordless sudo
        sudoersFile = pkgs.writeText "sudoers-dev" ''
          dev ALL=(ALL) NOPASSWD: ALL
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

            # Add user and sudoers via extraCommands (compatible with this n2c version)
            extraCommands = ''
              mkdir -p home/dev

              # ensure wheel group exists (gid 10)
              if ! grep -q '^wheel:' etc/group 2>/dev/null; then
                echo 'wheel:x:10:' >> etc/group
              fi

              # add dev user to /etc/passwd (uid/gid 1000)
              if ! grep -q '^dev:' etc/passwd 2>/dev/null; then
                echo 'dev:x:1000:1000:dev:/home/dev:${pkgs.fish}/bin/fish' >> etc/passwd
              fi

              # create shadow entry to disable password for dev
              if [ ! -f etc/shadow ] || ! grep -q '^dev:' etc/shadow 2>/dev/null; then
                umask 077
                echo 'dev:!:18500:0:99999:7:::' >> etc/shadow
              fi

              mkdir -p etc/sudoers.d
              cp ${sudoersFile} etc/sudoers.d/dev
              chmod 0440 etc/sudoers.d/dev

              chown -R 1000:1000 home/dev
            '';

            config = {
              Cmd = [ "${pkgs.fish}/bin/fish" ];
              Env = [ "SHELL=${pkgs.fish}/bin/fish" ];
              WorkingDir = "/home/dev";
              User = "dev";
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