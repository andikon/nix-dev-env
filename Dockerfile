FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive 
ENV HOME=/home/dev 
ENV USER=dev
	
RUN apt-get update && apt-get install -y \
    curl \
	build-essential \
    git \
	sudo

RUN useradd -m dev
RUN echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER dev

RUN curl -sL https://nixos.org/nix/install | sh -s -- --no-daemon \
 && mkdir -p ~/.config/nix \
 && echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

ENV PATH=/home/dev/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH

RUN nix --extra-experimental-features "nix-command flakes" \
    profile add github:andikon/nix-config#cli-packages

ENV PATH=/home/dev/.nix-profile/bin:$PATH

RUN sudo chsh -s /home/dev/.nix-profile/bin/fish dev
WORKDIR /home/dev

RUN nvim --headless "+Lazy! sync" +qa
RUN nvim --headless ":TSUpdate all" +qa

CMD ["/home/dev/.nix-profile/bin/fish", "-l"]
