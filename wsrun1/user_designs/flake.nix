{
  nixConfig = {
    extra-substituters = [
      "https://nix-cache.fossi-foundation.org"
    ];
    extra-trusted-public-keys = [
      "nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs="
    ];
  };

  inputs = {
    nix-eda.url = "github:fossi-foundation/nix-eda/7.8.0";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
  };

  outputs =
    {
      self,
      nix-eda,
      flake-utils,
      flake-compat,
    }:
    let
      nixpkgs = nix-eda.inputs.nixpkgs;
      lib = nixpkgs.lib;
    in
    {
      # Common
      overlays = {
        default = lib.composeManyExtensions [
          (nix-eda.composePythonOverlay (
            pkgs': pkgs: pypkgs': pypkgs:
            let
              callPythonPackage = lib.callPackageWith (pkgs' // pkgs'.python3.pkgs);
            in
            {
              fasm = callPythonPackage ./fasm.nix { };
            }
          ))
          (final: prev: {
            nextpnr = prev.nextpnr.overrideAttrs {
              version = "3e53a0bf";
              src = prev.fetchFromGitHub {
                owner = "YosysHQ";
                repo = "nextpnr";
                rev = "3e53a0bf44d13c0de603dd089a323ea85d67d4ef";
                hash = "sha256-zxdd0D2/YamP9djRsb613ktPofxbBUNS0jK0iZdtPhU=";
                fetchSubmodules = true;
              };
              cmakeFlags = [
                "-DCURRENT_GIT_VERSION=nextpnr-3e53a0bf"
                "-DARCH=generic"
                "-DBUILD_TESTS=ON"
                "-DUSE_OPENMP=ON"
                # `Compatibility with CMake < 3.5 has been removed from CMake.`
                "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
              ];
            };
          })
        ];
      };

      # Packages
      legacyPackages = nix-eda.forAllSystems (
        system:
        import nix-eda.inputs.nixpkgs {
          inherit system;
          overlays = [
            nix-eda.overlays.default
            self.overlays.default
          ];
        }
      );

      # Development Shells
      devShells = nix-eda.forAllSystems (
        system:
        let
          pkgs = self.legacyPackages."${system}";
          callPackage = lib.callPackageWith pkgs;
          python-env = (pkgs.python3.withPackages (ps: with ps; [ pkgs.python3.pkgs.fasm ]));
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.nextpnr
              pkgs.yosys
              python-env
            ];
          };
        }
      );
    };
}
