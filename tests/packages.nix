# Specify some extra packages in profiles.
{
  config.xdg.enable = true;

  config.programs.emacs = {
    enable = true;
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
}
