{ pkgs, ... }:
{

  sensible.docker.enable = true;
  programs.wireshark.enable = true;

  environment.systemPackages = with pkgs; [
    krita wireshark unstable.signal-desktop monocraft bruno
    rpi-imager gimp proton-vpn hyprmon moonlight-qt
    libreoffice inkscape gajim karere
  ];
}
