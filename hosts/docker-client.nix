{
  pkgs,
  user,
  ...
}: {
  virtualisation.docker = {
    enable = true;
    # Rootless mode gör att du kan köra containers utan sudo,
    # vilket är säkrare och smidigare på en desktop.
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # Lägger till din användare ('cindy') i docker-gruppen
  # så att du har rättigheter att prata med tjänsten.
  users.users.${user}.extraGroups = ["docker"];
}
