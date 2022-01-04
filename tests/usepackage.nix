# Parse use-package declarations
{
  config = {
    programs.emacs = {
      enable = true;
      chemacs.profiles.default = {
        extraPackages = ep: [ ep.rainbow-mode ep.fake-package-proxy ];
        packagesFromUsePackage.enable = true;
        overrides = _: super: { fake-package-proxy = super.ace-window; };
        initFile.text = ''
          (setq initial-scratch-message
            ";; This is #31f9ab meant to demonstrate #9aa1c0 rainbow-mode\n\n")
          (use-package avy-zap
            :ensure t
            :bind (("C-x !" . #'avy-zap-to-char)))
          (use-package rainbow-mode
            :hook lisp-interaction-mode)
          (use-package ace-window
            :bind (("C-x &" . #'ace-window)))
        '';
      };

      chemacs.profiles.extfile = {
        packagesFromUsePackage.enable = true;
        packagesFromUsePackage.alwaysEnsure = true;
        initFile.source = ./usepackage-init.el;
      };
    };
  };

  script = ''
    assertEmacsParse "$hf/.emacs-profiles.el"

    elisp=$(grep nix-elisp-bundle "$hf/.emacs-profiles.el" | cut -f2 -d'"' | head -1)
    (ls "$elisp/share/emacs/site-lisp/elpa" | grep use-package) || fail "Expected use-package"
    (ls "$elisp/share/emacs/site-lisp/elpa" | grep avy-zap) || fail "Expected avy-zap"
    (ls "$elisp/share/emacs/site-lisp/elpa" | grep rainbow-mode) || fail "Expected rainbow-mode"
    (ls "$elisp/share/emacs/site-lisp/elpa" | grep ace-window) || fail "Expected ace-window"
  '';
}
