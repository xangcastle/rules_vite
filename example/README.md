# Example monorepo

Five small applications sharing one shadcn/ui component set, built with a
single Bazel workspace and a single pnpm lockfile. It is a reduced version
of a production layout: instead of every app vendoring its own copy of each
component, `components/` is the one source of truth and every build injects
it.

## Layout

```
MODULE.bazel            bazel_dep rules_vite, node + npm toolchains,
                        chadcn extension pinned by shadcn-lock.json
BUILD.bazel             npm_link_all_packages (one linked tree for all apps)
package.json            every dependency of every app
pnpm-lock.yaml          the one lockfile
shadcn-lock.json        sha256 pins for the 21 registry components
components/
  lib/cn.ts             the cn helper the components import
  styles/globals.css    tailwind v4 theme
apps/
  dashboard/            sidebar shell, KPI cards, data table
  forms/                controlled form + the vitest suite
  chat/                 avatar-based message list
  marketing/            landing page with accordion FAQ
  settings/             dialogs, dropdowns, switches, selects, tooltips
```

The shared component set comes from the chadcn extension: the lock pins
each registry JSON by sha256, the extension extracts the sources into a
tree that mirrors the registry layout (ui/, lib/, hooks/) with
registry-internal imports rewritten to relative paths, and every app
injects `@shadcn//:all_files` plus the local `//components:src` (cn
helper and theme) in one shot. Builds resolve both from the same lock.

## Build

```sh
bazel build //apps/...
```

Each `apps/<name>:app` target stages the app package, injects
`//components:src` at `components/` inside it, links only the per-package
`node_modules` entries the app declared in `deps`, and runs `vite build`
sandboxed with network blocked. The bundle lands in `dist` as a TreeArtifact.

## Test

```sh
bazel test //apps/forms:unit_tests
```

## Dev server

```sh
bazel run //apps/dashboard:app.dev
```

Sources are served live from the workspace with vite's native HMR — editing
any file under `components/src/` propagates to every running application,
because the dev server links the same directory the build injects.

## Module resolution

The example is a standalone Bazel module nested inside the ruleset, so its
`MODULE.bazel` carries a `local_path_override` that resolves `rules_vite`
to the parent directory — plain `bazel build //apps/...` works from a
clean checkout. Delete the override once rules_vite is published to the
BCR and the `bazel_dep` version resolves on its own.
