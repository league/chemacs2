# Enable emacs and a default profile. Ensure it puts stuff in expected places.
{
  config.programs.emacs = {
    enable = true;
    chemacs.profiles.default = {
      initFile.text = ''
        (message "basic.default")
      '';
    };
  };

  script = ''
    assertFileExists   "$hf/.emacs.d/early-init.el"
    assertFileExists   "$hf/.emacs.d/init.el"
    assertEmacsParse   "$hf/.emacs-profiles.el"
    assertFileContains "$hf/.emacs-profiles.el" "/home/basic/.emacs-profiles/default"
    assertFileContains "$hf/.emacs-profiles/default/init.el" "message"

    assertFileDoesntExist "$hp/bin/git"
  '';
}
