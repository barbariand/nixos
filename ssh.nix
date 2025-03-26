let
  github = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKWc4yBF7ji/ceoR322U5NHxIcxkFLqQJFAHR25Q0F2i";
  lenovo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOnR00BoyVKj+4mWb2UH1IwfMYHkvlwfu1f2R2STPst";
  home_computer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKAtTqXhEwlDPmpAQuShQlprHQn6iD4ODnzFEaRTtwUC";
in {
  users = [lenovo home_computer github];
  systems = [];
  keyFiles = ["~/.ssh/github" "~/.ssh/id_ed25519"];
}
