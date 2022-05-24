{
  description =
    "Configure multiple emacs profiles with nix, home-manager, and chemacs.";

  # Both home-manager and pre-commit-hooks reference a nixpkgs. If we keep both,
  # things will build but there is duplication that slows down CI. Standardize
  # on the nixpkgs in home-manager, but then we need to pin PCH so it doesn't
  # require tools that are only in bleeding-edge nixpkgs.

  inputs.home-manager.url = "github:nix-community/home-manager";

  inputs.emacs-overlay = {
    url = "github:nix-community/emacs-overlay";
    inputs.nixpkgs.follows = "home-manager/nixpkgs";
  };

  inputs.pre-commit-hooks = {
    url =
      "github:cachix/pre-commit-hooks.nix/ff9c0b459ddc4b79c06e19d44251daa8e9cd1746";
    inputs.nixpkgs.follows = "home-manager/nixpkgs";
    inputs.flake-utils.follows = "emacs-overlay/flake-utils";
  };

  outputs = inputs@{ self, home-manager, pre-commit-hooks, ... }:
    let
      eachSystem =
        lib.genAttrs [ "aarch64-darwin" "x86_64-linux" "x86_64-darwin" ];
      inherit (home-manager.inputs) nixpkgs;
      inherit (nixpkgs) lib;
      testUsers = import ./tests;
      pkgs = eachSystem (system:
        import nixpkgs {
          inherit system;
          overlays = [ inputs.emacs-overlay.overlay ];
        });
    in {
      homeModule = import ./chemacs.nix;

      # User profiles for testing features.
      homeConfigurations = eachSystem (system:
        lib.mapAttrs (username: test:
          home-manager.lib.homeManagerConfiguration {
            inherit system username;
            configuration = test.config;
            pkgs = pkgs.${system};
            homeDirectory = "/home/${username}";
            extraModules = [ self.homeModule ];
            extraSpecialArgs = { hmPath = home-manager.outPath; };
          }) testUsers);

      # All test configurations should have buildable activation packages.
      checks = eachSystem (system:
        lib.mapAttrs (name:
          let hm = self.homeConfigurations.${system}.${name}.activationPackage;
          in test:
          if test ? script then
            pkgs.${system}.runCommand name { } ''
              source "${tests/assertions.sh}"
              hf="${hm}/home-files"
              hp="${hm}/home-path"
              ${test.script}
              touch "$out"
            ''
          else
            hm) testUsers // {
              pre-commit = pre-commit-hooks.lib.${system}.run {
                src = ./.;
                hooks.nixfmt.enable = true;
                hooks.nix-linter.enable = true;
                hooks.yamllint.enable = true;
              };
            });

      # Create one NixOS VM containing each test configuration in a separate
      # user account.
      nixosConfigurations.chemacs = let initialPassword = "secret123";
      in lib.nixosSystem {
        system = "x86_64-linux";
        pkgs = pkgs.x86_64-linux;
        modules = [
          home-manager.nixosModules.home-manager
          ({ modulesPath, pkgs, ... }: {
            imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
            networking.hostName = "chemacs";
            system.stateVersion = "22.05";
            services.openssh.enable = true;
            users.users = lib.mapAttrs (_: _: {
              isNormalUser = true;
              inherit initialPassword;
            }) testUsers // {
              root = { inherit initialPassword; };
            };
            environment.systemPackages = [ pkgs.tree pkgs.kitty.terminfo ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [
              self.homeModule
              {
                home.stateVersion = "21.05";
                # https://github.com/nix-community/home-manager/issues/1262
                manual.manpages.enable = false;
              }
            ];
            home-manager.users = lib.mapAttrs (_: test: test.config) testUsers;
          })
        ];
      };

      # Create run scripts for each test configuration.
      apps = eachSystem (system:
        lib.listToAttrs (lib.concatLists (lib.mapAttrsToList (username: home:
          lib.mapAttrsToList (name: profile: {
            name = "${username}-${name}";
            value.type = "app";
            value.program = toString profile.run;
          }) home.config.programs.emacs.chemacs.profiles)
          self.homeConfigurations.${system})));

      # Developer should have access to nix tools and home-manager executable.
      devShell = eachSystem (system:
        let ps = pkgs.${system};
        in ps.mkShell {
          inherit (self.checks.${system}.pre-commit) shellHook;
          buildInputs = [ home-manager.packages.${system}.home-manager ]
            ++ (with pre-commit-hooks.packages.${system}; [
              nixfmt
              nix-linter
              pre-commit
              yamllint
            ]);
        });
    };
}
