{
  inputs.devenv.url = "github:cachix/devenv/v1.11.2";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/25.11";

  outputs =
    {
      flake-parts,
      nixpkgs,
      devenv,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      types = lib.types;
      taskType = lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            after = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
            before = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
          };

          freeformType = types.attrsOf types.anything;
        }
      );
      devenvModule =
        {
          lib,
          pkgs,
          config,
          ...
        }:
        let
          settingsFormat = pkgs.formats.yaml { };
          dag = (import ./lib/dag.nix) {
            inherit lib;
            hm = {
              dag = dag;
            };
          };
          enterShellTaskName = "devenv:enterShell";

          enterShellSet = lib.filterAttrs (
            name: task: (builtins.elem enterShellTaskName (task.before ++ task.after))
          ) config.tasks;
          enterShellDag = lib.mapAttrs (
            name: task: dag.entryBetween task.before task.after task
          ) enterShellSet;

          enterShellSort = dag.topoSort enterShellDag;

          enterShell = lib.concatStrings (
            map (
              { data, name }:
              ''
                # ${name}
                ${data.exec}
              ''
            ) enterShellSort.result
          );
        in
        {
          disabledModules = [
            "${devenv.sourceInfo.outPath}/src/modules/tasks.nix"
            "${devenv.sourceInfo.outPath}/src/modules/flake-compat.nix"
          ];

          options = {
            # We need to re-define this options since other modules depend on it.
            tasks = lib.mkOption {
              type = types.attrsOf taskType;
              description = "A set of tasks.";
            };

            process.managers.process-compose-mini = {
              enable = lib.mkEnableOption "noop as the process manager" // {
                internal = true;
              };
            };

            process.managers.noop = {
              enable = lib.mkEnableOption "noop as the process manager" // {
                internal = true;
              };
            };
          };

          config = lib.mkMerge [
            {
              process.manager.implementation = lib.mkDefault "process-compose-mini";
              enterShell = enterShell;
            }

            (lib.mkIf (config.process.managers.noop.enable) {
              process.manager.command = "exit 1";
            })

            (lib.mkIf (config.process.managers.process-compose-mini.enable) {
              # Diable the regular manager system.
              process.manager.command = "exit 1";

              packages = [ pkgs.process-compose ];
              env.PC_CONFIG_FILES = settingsFormat.generate "process-compose.yaml" {
                version = "0.5";
                is_strict = true;
                processes = lib.mapAttrs (
                  name: value: { command = value.exec; } // value.process-compose
                ) config.processes;
              };
              env.PC_SOCKET_PATH = "${config.env.DEVENV_STATE}/process-compose.socket";
            })
          ];
        };

      flakeModule = {
        imports = [
          devenv.flakeModule
        ];

        perSystem =
          { ... }:
          {
            devenv.modules = [ devenvModule ];
          };
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Main API:
      flake.flakeModule = flakeModule;
      flake.devenvModule = devenvModule;

      # For local testing:
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [ flakeModule ];
      perSystem =
        { ... }:
        {
          devenv.shells.default =
            { config, ... }:
            {
              # An example of enterShell support.

              languages.python = {
                enable = true;
                venv.enable = true;
              };

              # Just an example for testing:
              processes.sleep = {
                exec = ''
                  echo "Sleeping..."
                  sleep infinity
                '';
              };
            };
        };
    };
}
