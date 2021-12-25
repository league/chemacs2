# Use XDG directories with a default profile. Ensure it puts stuff in expected
# places.
{
  config.xdg.enable = true;

  config.programs.emacs = {
    enable = true;
    chemacs.profiles.default = {
      initFile.text = ''
        (message "basic-xdg.default")
      '';
    };
  };

  script = ''
    assertFileExists   "$hf/.config/emacs/early-init.el"
    assertFileExists   "$hf/.config/emacs/init.el"
    assertEmacsParse   "$hf/.config/chemacs/profiles.el"
    assertFileContains "$hf/.config/chemacs/profiles.el" "/home/basic-xdg/.config/chemacs/default"
    assertFileContains "$hf/.config/chemacs/default/init.el" "message"
  '';
}
