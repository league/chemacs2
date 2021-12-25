{
  description = "";

  inputs.home-manager.url = "github:nix-community/home-manager";
  inputs.emacs-overlay.url =
    "github:nix-community/emacs-overlay/23c8464f4527a2b19f6b4776378dd03b8289aa85";

  outputs = inputs@{ self, home-manager, ... }:
    let
      systems = [ "x86_64-linux" ];
      inherit (home-manager.inputs) nixpkgs;
      inherit (home-manager.inputs.nixpkgs) lib;
      testUsers = import ./tests;
      pkgs = lib.genAttrs systems (system:
        import nixpkgs {
          inherit system;
          overlays = [ inputs.emacs-overlay.overlay ];
        });
    in {
      inherit pkgs;

      homeModule = import ./chemacs.nix;

      # User profiles for testing features.
      homeConfigurations = lib.mapAttrs (username: test:
        home-manager.lib.homeManagerConfiguration {
          inherit username;
          configuration = test.config;
          system = "x86_64-linux";
          pkgs = pkgs.x86_64-linux;
          homeDirectory = "/home/${username}";
          extraModules = [ self.homeModule ];
          extraSpecialArgs = { hmPath = home-manager.outPath; };
        }) testUsers;

      # All test configurations should have buildable activation packages.
      checks.x86_64-linux = lib.mapAttrs (name:
        let hm = self.homeConfigurations.${name}.activationPackage;
        in test:
        if test ? script then
          pkgs.x86_64-linux.runCommand name { } ''
            source "${tests/assertions.sh}"
            hf="${hm}/home-files"
            hp="${hm}/home-path"
            ${test.script}
            touch "$out"
          ''
        else
          hm) testUsers;

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
            services.openssh.enable = true;
            virtualisation.qemu.networkingOptions = [
              "-net nic,netdev=user.0,model=virtio"
              ''-netdev user,id=user.0,hostfwd=tcp::7722-:22"$QEMU_NET_OPTS"''
            ];
            users.users = lib.mapAttrs (_: _: {
              isNormalUser = true;
              inherit initialPassword;
            }) testUsers // {
              root = { inherit initialPassword; };
            };
            environment.systemPackages = [ pkgs.tree pkgs.kitty.terminfo ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules =
              [ self.homeModule { home.stateVersion = "21.05"; } ];
            home-manager.users = lib.mapAttrs (_: test: test.config) testUsers;
          })
        ];
      };

      # Developer should have access to nix tools and home-manager executable.
      devShell = lib.genAttrs systems (system:
        let ps = pkgs.${system};
        in ps.mkShell {
          buildInputs = [
            home-manager.packages.${system}.home-manager
            ps.nix-linter
            ps.nixfmt
          ];
        });
    };
}
