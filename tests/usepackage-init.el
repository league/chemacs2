;; Hello world!
(setq initial-scratch-message
      ";; This is #31f9ab meant to demonstrate #c09aa1 rainbow-mode\n\n")
(use-package rainbow-mode
  :hook lisp-interaction-mode)
(use-package avy-zap
  :bind (("C-x !" . #'avy-zap-to-char)))
