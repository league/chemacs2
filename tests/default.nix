{
  no-emacs = import ./no-emacs.nix;
  basic = import ./basic.nix;
  basic-xdg = import ./basic-xdg.nix;
  custom-parent = import ./custom-parent.nix;
  various = import ./various.nix;
  packages = import ./packages.nix;
  native-comp = import ./native-comp.nix;
}
