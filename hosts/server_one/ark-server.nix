{ config, pkgs, ... }:
{
  services.ark-server = {
    enable = true;
    # ... dina andra inställningar (adminPassword etc)

    sessionName = "Cindy's Ark World";
    adminPassword = "ditt-hemliga-lösenord";

    map = "CrystalIsles";
    # Här klistrar vi in alla IDs separerade med kommatecken (utan mellanslag efter kommat)
    mods = "478525616,731604991,761535755,821530042,1402519919,1404697612,1522327484,2357644511,2804332920,2992724150";
  };
}
