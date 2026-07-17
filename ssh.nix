{ config, pkgs, lib, user ? "cindy", ... }:

let
  sshKeys = import ./ssh-keys.nix;
in
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users = {
    root.openssh.authorizedKeys.keys = sshKeys.users ++ sshKeys.systems;
    ${user}.openssh.authorizedKeys.keys = sshKeys.users;
  };

  home-manager.users.${user} = {
    services.ssh-agent.enable = true;

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
        "*" = {
          AddKeysToAgent = "yes";
          IdentityFile = sshKeys.keyFiles;
        };
      };
    };
  };
}
