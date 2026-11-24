# Roadmap

## Phase 2 · Package management

Each project has an `as.json` manifest with `name`, `version` and a `dependencies` map. Each key is a GitHub repository in `user/repo` form and its value is a tag. The package manager accepts `user/repo@tag`, resolves the tag to a commit, then fetches the GitHub tarball for that commit. It installs the contents under `as_modules/<user>/<repo>/`.

Commit `as.lock` with the project. Each entry records the repository, tag, resolved commit and SHA-256 of the archive. Reinstalls use the locked commit and verify the archive hash before extraction. An explicit dependency update can resolve a tag again and replace its lock entry. Cache verified archives by hash so locked projects can reinstall offline. Report which dependency is missing if the cache cannot satisfy an offline install.

Use the existing `IncludeResolver`. For `#include "user/repo/file.as"`, try the matching dependency and its subpath under the project's `as_modules` directory before the existing relative lookup from the containing script. [ScriptLoader.h](../src/runtime/ScriptLoader.h)

Extend the existing command registry. [Commands.cpp](../src/cli/Commands.cpp)

- **init** creates a starter manifest.
- **install** restores the dependency tree from the manifest and lockfile. With a `user/repo@tag` argument it adds the dependency and updates the lock.
- **run** continues to run explicit scripts and uses the project-aware include resolver when the script belongs to a project.

The installer runs no package scripts. Pin hashes in the lockfile, validate package paths before extraction and reject entries that can escape the destination.

### Open questions

- Should the first release resolve transitive dependencies? If so, how should it handle two tags for the same repository?
- How should projects choose a default script for run, and how should nested manifests affect project discovery?
- Where should the cache live on each OS, and when should unused archives be pruned?

## JIT

The `JitProvider` interface is already in place and 0.1 ships with `NullJit`. A real provider must build against AngelScript 2.39 on its supported platforms, pass the script fixtures with JIT enabled, and document its debugger policy. Keep the interpreter active in DAP sessions unless the provider can preserve breakpoints, stepping and inspection and passes the debugger fixtures.
