FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive 
ENV HOME=/home/dev 
ENV USER=dev
	
RUN rm -rf /etc/apt/sources.list /etc/apt/sources.list.d/* \
 && printf "deb http://de.archive.ubuntu.com/ubuntu noble main restricted universe multiverse\n" > /etc/apt/sources.list \
 && printf "deb http://de.archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse\n" >> /etc/apt/sources.list \
 && printf "deb http://de.archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse\n" >> /etc/apt/sources.list \
 && apt-get update

RUN apt-get install -y \
    curl \
	build-essential \
    git \
    sudo \
    ca-certificates

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

RUN git clone https://github.com/andikon/dotfiles.git ~/.dotfiles \
    && cd ~/.dotfiles \
    && stow -t ~ fish nvim scripts tmux

RUN sudo chmod +x /home/dev/.local/bin/*

RUN sudo chsh -s /home/dev/.nix-profile/bin/fish dev
WORKDIR /home/dev

RUN nvim --headless "+Lazy! sync" +qa
RUN nvim --headless ":TSUpdate all" +qa

ENTRYPOINT ["/home/dev/.local/bin/container_startup_script.sh"]
CMD ["/home/dev/.nix-profile/bin/fish", "-l"]
