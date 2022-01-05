{ lib, pkgs, config, ... }:
let
  cfg = config.programs.emacs;
  inherit (config) xdg;
  inherit (config.home) homeDirectory;
  inherit (config.home) username;

  # Helper functions to convert nix values and attrs to elisp.
  elisp = rec {
    str = s: ''"'' + lib.escape [ "\\" ''"'' ] s + ''"'';
    toStr = x: str (toString x);
    bool = p: if p then "t" else "nil";
    cons = x: y: "(${x} . ${y})";
    consStr = x: y: cons (str x) (str y);
    truthy = x: x != null && x != [ ] && x != { } && x != false;
    mapIf = f: x: lib.optionals (truthy x) (f x);
    list = sep: xs: "(" + lib.concatStringsSep sep xs + ")";
    alist = sep: bind: attrs: list sep (lib.mapAttrsToList bind attrs);
    relTo = dir: path:
      if lib.hasPrefix "/" path || lib.hasPrefix "~" path then
        path
      else
        dir + "/" + path;
    relToStr = dir: path: str (relTo dir path);
    nl = indent: "\n" + lib.fixedWidthString indent " " "";
  };

  # This is a cut-down version of the file-type submodule in home-manager. That
  # one must be bound as an attribute set, like ‘home.file.NAME’. Here, the NAME
  # can be hard-coded so that fileType can be used for emacs.initFile, etc.
  fileType = name:
    lib.types.submodule ({ config, ... }: {

      options.text = lib.mkOption {
        description = ''
          Text of the file. If this option is null then ‘source’ must be set.
        '';
        type = with lib.types; nullOr lines;
        default = null;
      };

      options.source = lib.mkOption {
        description = ''
          Path of the source file. If ‘text’ is non-null then this option will
          automatically point to a file containing that text.
        '';
        type = lib.types.path;
        default = pkgs.writeTextFile {
          inherit (config) text;
          name = lib.hm.strings.storeFileName name;
        };
      };

    });

in {
  options.programs.emacs = {

    userDir = lib.mkOption {
      description = ''
        Location of the user’s main emacs directory. Defaults to
        "$XDG_CONFIG_HOME/emacs" if ‘xdg.enable’ is set; otherwise ".emacs.d".
        It can be set manually if, for example, you’re using XDG for other
        things, but want to use the traditional directory for Emacs. More exotic
        settings may be possible if you make emacs aware of the location
        somehow. If either ‘initFile’ or ‘earlyInitFile’ are set, then the
        activation script prints a warning if this ‘userDir’ would be superseded
        by an existing "~/.emacs" or other file.
      '';
      type = lib.types.str;
      default = if xdg.enable then "${xdg.configHome}/emacs" else ".emacs.d";
    };

    earlyInitFile = lib.mkOption {
      description = ''
        Content of ‘early-init.el’ in the user’s main emacs directory.
      '';
      type = with lib.types; nullOr (fileType "early-init.el");
      default = null;
    };

    initFile = lib.mkOption {
      description = ''
        Content of ‘init.el’ in the user’s main emacs directory.
      '';
      type = with lib.types; nullOr (fileType "init.el");
      default = null;
    };

    chemacs.defaultUserParentDir = lib.mkOption {
      description = ''
        Default location for chemacs profile directories. It's fine to set
        ‘chemacs.profiles.NAME.userDir’ to anywhere accessible by the user, but
        by default we'll set them to the sub-directory NAME within this
        directory.
      '';
      type = lib.types.str;
      default = if xdg.enable then
        "${xdg.configHome}/chemacs"
      else
        "${homeDirectory}/.emacs-profiles";
    };

    chemacs.profiles = let
      profileType = lib.types.submodule ({ name, config, ... }: {

        options.userDir = lib.mkOption {
          description = ''
            The user-emacs-directory for this profile. Upon startup, emacs will
            look here for init and data files. By default, use a sub-directory
            NAME within ‘defaultUserParentDir’.
          '';
          type = lib.types.str;
          default = "${cfg.chemacs.defaultUserParentDir}/${name}";
        };

        options.customFilePath = lib.mkOption {
          description = ''
            The file where ‘M-x customize’ stores its customizations. If null,
            and the ‘custom-file’ variable is still unset after loading the
            profile's ‘init.el’, then it will get set to the profile’s
            ‘init.el’. If this path begins with a slash or tilde, we use it as
            is. Otherwise, we make it relative to this profile’s ‘userDir’.
          '';
          type = with lib.types; nullOr str;
          default = null;
        };

        options.serverName = lib.mkOption {
          description = ''
            Distinguish different instances with ‘emacsclient -s SERVER-NAME’.
          '';
          type = with lib.types; nullOr str;
          default = null;
        };

        options.env = lib.mkOption {
          description = ''
            Environment variables to set before loading the profile.
          '';
          type = with lib.types; attrsOf str;
          default = { };
        };

        options.straight.enable = lib.mkEnableOption "Straight package manager";

        options.earlyInitFile = lib.mkOption {
          description = ''
            Content of ‘early-init.el’ in this profile’s emacs directory.
          '';
          type = with lib.types; nullOr (fileType "early-init.el");
          default = null;
        };

        options.initFile = lib.mkOption {
          description = ''
            Content of ‘init.el’ in this profile’s emacs directory.
          '';
          type = with lib.types; nullOr (fileType "init.el");
          default = null;
        };

        options.extraPackages = lib.mkOption {
          description = ''
            Extra packages available to Emacs.
          '';
          type = lib.types.nullOr lib.hm.types.selectorFunction;
          default = null;
        };

        options.packagesFromUsePackage = {
          enable = lib.mkEnableOption
            "selecting packages by parsing use-package declarations in ‘initFile’";
          alwaysEnsure =
            lib.mkEnableOption "emulation of ‘use-package-always-ensure’";
        };

        options.overrides = lib.mkOption {
          description = ''
            Allows overriding packages within the Emacs package set.
          '';
          type = lib.hm.types.overlayFunction;
          default = _self: _super: { };
        };

        options.deps = lib.mkOption {
          description = ''
            An emacs dependencies bundle, produced by withPackages.
            This is meant to be read-only. The default bundle is constructed
            from ‘packagesFromUsePackage’, ‘extraPackages’, and/or ‘overrides’.
            Parsing use-package declarations assumes the nix-community
            emacs-overlay has been applied.
          '';
          type = with lib.types; nullOr package;
          default = if config.packagesFromUsePackage.enable then
            (pkgs.emacsWithPackagesFromUsePackage {
              config = if config.initFile.text != null then
                config.initFile.text
              else
                builtins.readFile config.initFile.source;
              package = cfg.package;
              extraEmacsPackages = if config.extraPackages != null then
                config.extraPackages
              else
                _: [ ];
              override = epkgs: epkgs.overrideScope' config.overrides;
              alwaysEnsure = config.packagesFromUsePackage.alwaysEnsure;
            }).deps
          else if config.extraPackages != null then
            (((pkgs.emacsPackagesFor cfg.package).overrideScope'
              config.overrides).withPackages config.extraPackages).deps
          else
            null;
        };

        options.lisp = lib.mkOption {
          description = ''
            An S-expression containing chemacs settings for this profile. Meant
            to be read-only.
          '';
          default = break:
            with elisp;
            alist (break 3) cons (lib.filterAttrs (_: truthy) {
              user-emacs-directory = relToStr homeDirectory config.userDir;
              custom-file = mapIf (relToStr config.userDir) config.customFilePath;
              server-name = mapIf str config.serverName;
              env = mapIf (alist (break 11) consStr) config.env;
              straight-p = mapIf bool config.straight.enable;
              nix-elisp-bundle = mapIf toStr config.deps;
            });
        };

        options.run = lib.mkOption {
          description = ''
            A script to run emacs with this profile in a temporary directory.
            Unlike running in a VM, this emacs will have access to your home
            directory, and can read/write files there. The temporary directory
            persists in /tmp until removed (just like the VM image persists).
            For this to work, you must already have our version of the chemacs2
            init files linked into your real home emacs directory. If you don't
            have that yet, stick to testing in a VM.
          '';
          type = lib.types.package;
          default = let
            ename = "emacs-${username}-${name}";
            tmp = "/tmp/nix-${ename}";
          in pkgs.writeShellScript ename ''
            mkdir -p "${tmp}"
            ${lib.optionalString (config.earlyInitFile != null)
            ''ln -sf "${config.earlyInitFile.source}" "${tmp}/early-init.el"''}
            ${lib.optionalString (config.initFile != null)
            ''ln -sf "${config.initFile.source}" "${tmp}/init.el"''}
            exec ${cfg.package}/bin/emacs --with-profile='${
              builtins.replaceStrings
              [ (elisp.relTo homeDirectory config.userDir) ] [ tmp ]
              (config.lisp (_: " "))
            }' "$@"
          '';
        };

      });
    in lib.mkOption {
      type = with lib.types; attrsOf profileType;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [

    # If we're using profiles, we'll need to configure chemacs. That means
    # generating a profiles file and installing our init files in the main emacs
    # dir.
    (lib.mkIf (cfg.chemacs.profiles != { }) (let
      profilesPath = if xdg.enable then
        "${xdg.configHome}/chemacs/profiles.el"
      else
        ".emacs-profiles.el";
      noteGenerated = ";; chemacs profile switcher, generated by home-manager";
      requireChemacs = ''
        ${noteGenerated}
        (require 'chemacs "${./chemacs.el}")
      '';
    in {
      programs.emacs.earlyInitFile.text = ''
        ${requireChemacs}
        (chemacs-load-user-early-init)
      '';

      programs.emacs.initFile.text = ''
        ${requireChemacs}
        (chemacs-load-user-init)
        ;; (package-initialize)
      '';

      home.file.${profilesPath}.text = with elisp; ''
        ${noteGenerated}
        ${alist (nl 1) (name: profile: cons (str name) (nl 2 + profile.lisp nl))
        cfg.chemacs.profiles}
      '';
    }))

    # Install main init files, if specified.
    (lib.mkIf (cfg.initFile != null) {
      home.file."${cfg.userDir}/init.el" = cfg.initFile;
    })

    (lib.mkIf (cfg.earlyInitFile != null) {
      home.file."${cfg.userDir}/early-init.el" = cfg.earlyInitFile;
    })

    # Install profile init files, if specified.
    {
      home.file = lib.mapAttrs' (_: profile:
        lib.nameValuePair "${profile.userDir}/early-init.el"
        profile.earlyInitFile)
        (lib.filterAttrs (_: p: p.earlyInitFile != null) cfg.chemacs.profiles);
    }

    {
      home.file = lib.mapAttrs' (_: profile:
        lib.nameValuePair "${profile.userDir}/init.el" profile.initFile)
        (lib.filterAttrs (_: p: p.initFile != null) cfg.chemacs.profiles);
    }

    # Warn if userDir will be superseded by an existing file.
    (lib.mkIf (cfg.initFile != null || cfg.earlyInitFile != null) {
      home.activation.checkEmacsDir =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [[ -e "$HOME/.emacs" ]]; then
            echo "Warning: ~/.emacs exists and will supersede ${cfg.userDir}"
          fi
          if [[ -e "$HOME/.emacs.el" ]]; then
            echo "Warning: ~/.emacs.el exists and will supersede ${cfg.userDir}"
          fi
          if [[ "${cfg.userDir}" != ".emacs.d" && -e "$HOME/.emacs.d" ]]; then
            echo "Warning: ~/.emacs.d exists and may supersede ${cfg.userDir}"
          fi
        '';
    })

    # If any profiles enable straight package manager, we'll also enable git at
    # the home level — otherwise the straight boostrap gives up. I considered
    # trying to set an exec-path containing git within the emacs profile, but
    # it's simpler to enable it for the user as a whole (who will probably want
    # git anyway).
    (lib.mkIf (lib.any (profile: profile.straight.enable)
      (lib.attrValues cfg.chemacs.profiles)) { programs.git.enable = true; })

  ]);
}
