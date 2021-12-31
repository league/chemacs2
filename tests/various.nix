# Various simple profile settings
{
  config.programs.emacs = {
    enable = true;
    chemacs.profiles.default = {
      customFilePath = "u/wot/custom.el";
      env.FANTA = "grape";
      serverName = "sabent";
    };
    chemacs.profiles.snow = {
      env.FLAVOR = "basil";
      straight.enable = true;
    };
  };

  script = ''
    assertEmacsParse   "$hf/.emacs-profiles.el"
    assertFileContains "$hf/.emacs-profiles.el" "u/wot/custom.el"
    assertFileContains "$hf/.emacs-profiles.el" "FANTA"
    assertFileContains "$hf/.emacs-profiles.el" "sabent"
    assertFileContains "$hf/.emacs-profiles.el" "basil"
    assertFileContains "$hf/.emacs-profiles.el" "(straight-p . t)"
    assertFileContains "$hf/.emacs-profiles.el" ".emacs-profiles/snow"

    assertFileExists   "$hp/bin/git"
  '';

}
