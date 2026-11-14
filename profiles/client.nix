{pkgs, ...}: {
  sensible.docker.enable = true;

  environment.systemPackages = with pkgs; [
    # GUI & Creative
    krita
    unstable.signal-desktop
    monocraft
    bruno
    rpi-imager
    gimp
    proton-vpn
    hyprmon
    moonlight-qt
    libreoffice
    inkscape
    gajim
    karere

    # Desktop Utilities
    bitwarden-cli
    bluetui
    brightnessctl
    pamixer
    xdg-utils

    # Heavy Toolchains & Language Servers
    bacon
    gcc
    rustup
    basedpyright
    ruff
    clang-tools
    gopls
    unstable.codegraph
    lua-language-server
    poppler-utils
    pyright
    solargraph
    svelte-language-server
    wakatime-cli

    # Spell Checking & Dictionaries
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    aspellDicts.en-science
    aspellDicts.sv
  ];
}
