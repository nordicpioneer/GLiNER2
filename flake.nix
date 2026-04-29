{
  description = "GLiNER2 packaged with setuptools (PEP 621) using nix flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # fix aarch64-linux block in gliner source, from bad platforms, onnxruntime errors with gpus
          config = {
            allowUnsupportedSystem = true;
          };

          overlays = [
            (final: prev: {
              python312Packages = prev.python312Packages.overrideScope (pyFinal: pyPrev: {
                gliner = pyPrev.gliner.overrideAttrs (old: {
                  meta = old.meta // {
                    badPlatforms = []; # see source blocking aarch64-linux https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/python-modules/gliner/default.nix#L57-L61
                  };
                });
              });
            })
          ];
        };
        #/ fix aarch64-linux block end

        python = pkgs.python312;
        pythonPackages = python.pkgs;

      in {
        packages = {
          gliner2 = pythonPackages.buildPythonApplication {
            pname = "gliner2";
            version = "1.3.0+maincommits"; # # TODO pin to tag v1.3.0 instead of main commit 
            src = ./.;

            pyproject = true;

            propagatedBuildInputs = with pythonPackages; [
              gliner
              peft
              pydantic
              requests
              urllib3
            ];

            doCheck = false;
          };

          default = self.packages.${system}.gliner2;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.gliner2;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.gliner2 ];

          packages = with pythonPackages; [
            pip
            setuptools
            wheel
          ];
        };
      }
    );
}
