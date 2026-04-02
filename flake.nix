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

        # Create sudoers file for passwordless sudo
        sudoersFile = pkgs.writeText "sudoers-dev" ''
          dev ALL=(ALL) NOPASSWD: ALL
        '';

        # Create an overlay derivation containing /home/dev and /etc entries
        imageOverlay = pkgs.runCommand "image-overlay" { } ''
          mkdir -p $out/home/dev/.local/share/chezmoi
          mkdir -p $out/etc/sudoers.d
          mkdir -p $out/etc

          # Copy dotfiles source for dev user
          cp -r ${dotfiles}/dotfiles/* $out/home/dev/.local/share/chezmoi/ || true

          # Initialize chezmoi and apply
          export HOME=$out/home/dev
          mkdir -p $HOME/.config/chezmoi
          ${pkgs.chezmoi}/bin/chezmoi --source=$HOME/.local/share/chezmoi init --apply --no-pager 2>/dev/null || true

          # Create /etc/passwd and /etc/group with dev and root entries
          cat > $out/etc/passwd <<EOF
          root:x:0:0:root:/root:/bin/sh
          dev:x:1000:1000:dev:/home/dev:${pkgs.fish}/bin/fish
          EOF

          cat > $out/etc/group <<EOF
          root:x:0:
          wheel:x:10:dev
          EOF

          # Create /etc/shadow entries (locked)
          umask 077
          cat > $out/etc/shadow <<EOF
          root:!:18500:0:99999:7:::
          dev:!:18500:0:99999:7:::
          EOF
          chmod 0400 $out/etc/shadow

          # Write sudoers file
          cp ${sudoersFile} $out/etc/sudoers.d/dev
          chmod 0440 $out/etc/sudoers.d/dev

          # Set proper permissions
          chown -R 1000:1000 $out/home/dev
        '';

        # ------------------------
        # nix2container image
        # ------------------------

        devContainer =
          n2c.buildImage {
            name = "docker.io/andrijkoenig/nix-dev-env";
            tag = "latest";

            # Use the combined root FS (base environment + overlay)
            copyToRoot = [ imageRoot imageOverlay ];

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