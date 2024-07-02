{zsh, lib}:
let temp = (builtins.readFile ./kitty-temes/themes/OneDark.conf);
lib.strings.concatStrings ['''' (bultins.toString temp)];
