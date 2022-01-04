# Set overrides for emacs packages
{
  config = {
    programs.emacs = {
      enable = true;
      chemacs.profiles.default = {
        # We ask for avy-zap, but actually redirect that to rainbow-mode.
        extraPackages = ep: [ ep.avy-zap ];
        overrides = _: super: { avy-zap = super.elpaPackages.rainbow-mode; };
        initFile.text = ''
          (add-hook 'prog-mode-hook #'rainbow-mode)
        '';
      };
    };
  };

  script = ''
    assertEmacsParse "$hf/.emacs-profiles.el"
    elisp=$(grep nix-elisp-bundle "$hf/.emacs-profiles.el" | cut -f2 -d'"')
    (ls "$elisp/share/emacs/site-lisp/elpa" | grep rainbow-mode) || fail "Expected rainbow-mode"
  '';
}
