# Use the emacsNativeComp branch with some packages.
{
  config = { pkgs, ... }: {
    xdg.enable = true;

    programs.emacs = {
      enable = true;
      package = pkgs.emacsNativeComp;
      chemacs.profiles.default = {
        extraPackages = ep: [ ep.avy-zap ];
        initFile.text = ''
          (define-key global-map (kbd "C-x !") #'avy-zap-to-char)
        '';
      };
      chemacs.profiles.rbow = {
        extraPackages = ep: [ ep.rainbow-mode ];
        initFile.text = ''
          (add-hook 'prog-mode-hook #'rainbow-mode)
        '';
      };
    };
  };
}
