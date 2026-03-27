rec {
  github = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIdaQe2WbF2N7kEzrcz2JNb7C+LdwVdnIH2L8Ok5Zfqh";
  lenovo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICsK1mn4aCbtTviKH9EgYBdQkue4NkiLyP2eiMKbqr31";
  home_computer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATgAc9Jsy22N5pB/+q71N9glTV4rlKnWeMd+RE/qFSf";
  raspberrypi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhW7urXQ2zLHRSRUkIWfYqdqB8q8gyJNJ/suuEF5rJi raspberrypi";
  users = [lenovo home_computer github];
  systems = [raspberrypi];
  keyFiles = ["~/.ssh/github" "~/.ssh/id_ed25519"];
}
