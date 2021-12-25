# Specify a default chemacs profile, but don't enable emacs, so nothing should
# be generated.
{
  config.programs.emacs.chemacs.profiles.default = { };

  script = ''
    assertFileDoesntExist "$hf/.emacs-profiles.el"
    assertFileDoesntExist "$hf/.config/chemacs/profiles.el"
    assertFileDoesntExist "$hp/bin/emacs"
  '';
}
