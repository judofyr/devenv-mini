# devenv-mini

[devenv](https://github.com/cachix/devenv) is a great tool for managing a local development environment, but later versions have introduced more bespoke functionality.
`devenv-mini` is a patched version of `devenv` which removes and simplifies part of this:

- **Removes tasks:**
  The whole task system is disabled and does nothing.
  This removes a whole set of binaries from the environment.
- **Removes flake-compat:**
  Removes various binaries (e.g. `devenv-flake-tasks`) which are devenv-specific.
- **`process-compose-mini` process manager:**
  A new `process-compose-mini` process manager is enabled by default.
  This bypasses most of the process management system and instead sets environment variable (i.e. `PC_CONFIG_FILES` and `PC_SOCKET_PATH`) so that you can invoke `process-compose` yourself.
- **`noop` process manager:**
  You can also set `process.manager.implementation = "noop"` to disable the process manager system yourself as well.

## Usage

### Option A: flake-parts module

The safest way of using `devenv-mini` is to use the `flakeModule`.
This uses the bundled version of `devenv` locked by `devenv-mini`.

```nix
{
  # 1: Import `devenv-mini` instead of `devenv`:
  inputs.devenv.url = "github:judofyr/devenv-mini";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs =
    { devenv, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # 2: Import flakeModule:
      imports = [ devenv.flakeModule ];

      perSystem =
        { ... }:
        {
          devenv.shells.default = {
            # 3: Regular definitions.
          };
        };
    };
}
```

### Option B: devenv module

Alternatively, you can access the `devenvModule` directly.
This gives you more control over the `devenv` module.

```nix
{
  # 1: Import your version of `devenv`:
  inputs.devenv.url = "github:cachix/devenv";

  # 2: Load devenv-mini with the version of `devenv`:
  inputs.devenv-mini.url = "github:judofyr/devenv-mini";
  inputs.devenv-mini.inputs.devenv.follows = "devenv";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs =
    { devenv-mini, ... }@inputs: …

    # 2: Inject `devenv-mini.devenvModule` somewhere.
}
```
