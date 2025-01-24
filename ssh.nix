let
  github=["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKWc4yBF7ji/ceoR322U5NHxIcxkFLqQJFAHR25Q0F2i"];
in {
  users=["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOnR00BoyVKj+4mWb2UH1IwfMYHkvlwfu1f2R2STPst" ]++github;
  systems=[];
  keyFiles=["~/.ssh/github"];
}
