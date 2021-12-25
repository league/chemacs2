# Place profiles in a custom parent-dir, but override it in one profile.
{
  config.programs.emacs = {
    enable = true;
    chemacs.defaultUserParentDir = "u/etc";
    chemacs.profiles.default = { };
    chemacs.profiles.one = {
      initFile.text = ''(message "custom-parent.one")'';
    };
    chemacs.profiles.two = {
      userDir = ".special";
      initFile.text = ''(message "custom-parent.two")'';
    };
  };

  script = ''
    assertEmacsParse   "$hf/.emacs-profiles.el"
    assertFileContains "$hf/.emacs-profiles.el" "/home/custom-parent/u/etc/default"
    assertFileContains "$hf/.emacs-profiles.el" "/home/custom-parent/u/etc/one"
    assertFileContains "$hf/.emacs-profiles.el" "/home/custom-parent/.special"
    assertFileContains "$hf/u/etc/one/init.el" "message"
    assertFileContains "$hf/.special/init.el" "message"
  '';
}
