{lib}: rec {
  isValidIPv4 = ip: let
    parts = lib.strings.splitString "." ip;
    isByte = s: let
      isNumeric = builtins.match "[0-9]+" s != null;
      n =
        if isNumeric
        then lib.strings.toInt s
        else null;
    in
      n != null && n >= 0 && n <= 255;
  in
    (builtins.length parts == 4) && (lib.all isByte parts);

  calcNetworkAddress = ip: prefixLength: let
    octets = map lib.strings.toInt (lib.strings.splitString "." ip);

    maskOctet = idx: let
      bits = lib.trivial.min 8 (lib.trivial.max 0 (prefixLength - (idx * 8)));
      shifts = [
        0
        128
        192
        224
        240
        248
        252
        254
        255
      ];
    in
      builtins.elemAt shifts bits;

    netOctets = lib.imap0 (idx: octet: builtins.bitAnd octet (maskOctet idx)) octets;
  in "${lib.concatStringsSep "." (map toString netOctets)}/${toString prefixLength}";

  isSameSubnet = ipA: ipB: prefixLength:
    (calcNetworkAddress ipA prefixLength) == (calcNetworkAddress ipB prefixLength);
}
