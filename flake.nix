{
  description = "Nix plugin for Lapce";

  inputs = {
    # <upstream>
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # <frameworks>
    flake-parts.url = "github:hercules-ci/flake-parts";

    # <tools>
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";

    nuenv.url = "github:DeterminateSystems/nuenv";
    nuenv.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    alejandra.url = "github:kamadorueda/alejandra";
    alejandra.inputs.nixpkgs.follows = "nixpkgs";

    # <packaging>
    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
    fenix.inputs.rust-analyzer-src.follows = "";
  };

  outputs = {...} @ inputs:
    with inputs;
      flake-parts.lib.mkFlake {inherit inputs;} {
        imports = [
          devenv.flakeModule
          treefmt-nix.flakeModule
        ];
        systems = ["x86_64-linux"];
        perSystem = {
          system,
          inputs',
          ...
        }: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [inputs.nuenv.overlays.nuenv];
            config.allowUnfree = true;
          };
          lib = pkgs.lib;
          create_one_line = name: script: "${pkgs.nuenv.mkScript {inherit name script;}}/bin/${name}";

          target = "wasm32-wasi";
          toolchain = with fenix.packages.${system};
            combine [
              minimal.rustc
              minimal.cargo
              targets.${target}.latest.rust-std
            ];

          crane_lib = (crane.mkLib pkgs).overrideToolchain toolchain;
          common_args = {
            src = ./.;
            doCheck = false;
            cargoExtraArgs = "--target ${target}";
          };
          lapce_crate = crane_lib.buildPackage (
            common_args
            // {
              nativeBuildInputs = [pkgs.tree];
              cargoBuildCommand = "cargo build --profile release -Z unstable-options --out-dir $out";
              installPhaseCommand = create_one_line "install-phase-command.nu" ''
                let static_files = [ icon.png README.md volt.toml ]
                for $file in $static_files { install -Dm644 $file $env.out }
              '';
            }
          );
        in {
          packages.default = lapce_crate;
          checks = {inherit lapce_crate;};

          _module.args = {inherit pkgs lib;};

          treefmt = {
            projectRootFile = "flake.lock";
            programs = {
              alejandra.enable = true;
              alejandra.package = inputs'.alejandra.packages.default;

              rustfmt.enable = true;
            };
          };
          devenv.shells.default = {
            name = "lapce-nix_shell";
            packages = with inputs';
              [
                alejandra.packages.default
                pkgs.lapce
              ]
              ++ [toolchain];
            enterShell =
              create_one_line "enter-shell.nu"
              ''
                print "Welcome to lapce-nix environment!"
                print "To publish plugin, run:"
                print $"('with-env { VOLTS_TOKEN: (open <path-to-key>) } { publish }' | nu-highlight)"
              '';
            scripts = {
              publish.exec = create_one_line "publish.nu" "nix build; (cd result; ~/.cargo/bin/volts --token $env.VOLTS_TOKEN publish)";
            };

            containers = lib.mkForce {};
          };
        };
      };
}
