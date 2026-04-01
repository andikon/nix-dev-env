# nix-dev-env

Cross-platform user package environment powered by Nix flakes.

This repository defines a reproducible set of user tools that can be installed on macOS and Linux using Nix. The goal is to maintain a single source of truth for development packages across machines and to produce a fully-baked Docker image that contains the same packages and selected Linux dotfiles for offline development.

---

## Requirements

Install Nix with flakes enabled (see https://nixos.org/manual/nix/stable/installation/installing-binary.html):

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Enable flakes (if not already enabled) by adding to `~/.config/nix/nix.conf`:

```bash
experimental-features = nix-command flakes
```

---

## Installation (local)

Clone the repository:

```bash
git clone https://github.com/<your-username>/dev-env.git
cd dev-env
```

Install the environment locally (macOS or Linux):

```bash
nix profile install .#default --profile dev-env
```

---

## Build the dev container image (Nix)

This flake provides a `devContainer` image (linux-only) that bakes packages and selected dotfiles into an OCI image.

Build and load into Docker (image uses fish as the default shell):

```bash
nix --extra-experimental-features 'nix-command flakes' build .#devContainer
# then
docker load < result
```

Export for offline transfer:

```bash
docker save <image-tag> -o dev-env.tar
```

Or use the provided helper script:

```bash
./scripts/build-image.sh
```

Note: The image pulls Linux-specific dotfiles from the `andikon/dotfiles` flake input (declared in `flake.nix`) during build. This is more declarative and reproducible than cloning at runtime. To change which dotfiles are used, update the `dotfiles.url` input in `flake.nix` or vendor the files into `./dotfiles`.

---

## CI: Build and publish image to Docker Hub

A GitHub Actions workflow is included at `.github/workflows/publish-image.yml` that builds the dev image with Nix and pushes it to Docker Hub. Configure repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` to allow pushing.

---

## Updating Packages

After pulling changes:

```bash
git pull
nix profile upgrade dev-env
```

---

## Reinstall / Apply Changes

If packages were modified in `flake.nix`:

```bash
nix profile install .#default --profile dev-env --force
```

---

## Adding Packages

Edit `flake.nix` in the `commonPackages` or platform-specific lists and then apply:

```bash
nix profile install .#default --profile dev-env --force
```

---

## Notes

- CI publishes a ready-to-pull image; for air-gapped machines prefer building locally and moving the tar via `docker save`/`docker load`.
- Ensure `./dotfiles` exists in the repo (submodule or copy) so baking includes your configurations.
