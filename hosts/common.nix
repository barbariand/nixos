{
  lib,
  pkgs,
  ...
}: {
  # Aktiverar moderna Nix-funktioner globalt på alla maskiner
  nix.settings.experimental-features = lib.mkForce ["nix-command" "flakes" "pipe-operators"];
documentation = {
    enable = true;
    man.enable = true;
    # Detta är den viktigaste raden:
    man.generateCaches = false;
    };
  # Overlays för att fixa problematiska Python-paket genom att stänga av check/tester
  nixpkgs.overlays = [
    (uFinal: uPrev: {
      python312 = uPrev.python312.override {
        packageOverrides = pyFinal: pyPrev: {
          whatthepatch = pyPrev.whatthepatch.overridePythonAttrs (_: {doCheck = false;});
          python-lsp-server = pyPrev.python-lsp-server.overridePythonAttrs (_: {doCheck = false;});
        };
      };
    })
  ];
}
