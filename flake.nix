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
          # crane_lib = (crane.mkLib pkgs).overrideToolchain rust_toolchain;
          # common_args = {
          #   src = crane_lib.cleanCargoSource (crane_lib.path ./.);
          #   doCheck = false;
          #   cargoExtraArgs = "--target wasm32-wasi";
          # };
          # lapce_crate = crane_lib.buildPackage (
          #   common_args
          #   // {
          #     # cargoArtifacts = crane_lib.buildDepsOnly common_args;
          #     cargoBuildCommand = "cargo build --profile release -Z unstable-options --out-dir .";
          #   }
          # );
        in {
          packages.default = let
            manifest = with builtins; fromTOML (readFile ./Cargo.toml);
          in
            (pkgs.makeRustPlatform {
              cargo = toolchain;
              rustc = toolchain;
            })
            .buildRustPackage {
              src = ./.;

              pname = manifest.package.name;
              version = manifest.package.version;

              cargoBuildFlags = ["--target=${target}"];
              doCheck = false;
              cargoLock = {
                lockFile = ./Cargo.lock;
                allowBuiltinFetchGit = true;
              };
            };

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
            name = "lapce-nil@shell";
            packages = with inputs';
              [
                alejandra.packages.default
                pkgs.lapce
              ]
              ++ [toolchain];
            enterShell = create_one_line "enterShell" "print 'Hello from Nushell!'";
            containers = lib.mkForce {};
          };
          # checks = {inherit lapce_crate;};
          # packages.default = lapce_crate;
        };
      };
}
