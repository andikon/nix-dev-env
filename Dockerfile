FROM ubuntu:24.04

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

RUN cd /tmp && git clone https://github.com/andikon/dotfiles .dotfiles

RUN cd /tmp/.dotfiles && \
    . /home/dev/.nix-profile/etc/profile.d/nix.sh && \
    nix build .#homeConfigurations.dev@docker.activationPackage && \
    ./result/activate

ENV PATH=/home/dev/.nix-profile/bin:$PATH

RUN rm -rf /tmp/.dotfiles

RUN sudo chsh -s /home/dev/.nix-profile/bin/fish dev
WORKDIR /home/dev

RUN nvim --headless "+Lazy! sync" +qa
RUN nvim --headless ":TSUpdate all" +qa

CMD ["/home/dev/.nix-profile/bin/fish", "-l"]