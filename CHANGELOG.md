# Changelog

## 0.1.0

Initial release.

- `vite_build`: real rule running `node` directly on a driver that stages
  the application into an ephemeral temp directory with the linked
  `node_modules` tree symlinked in, then runs vite with the project root
  pinned to the stage. Sandboxed with `block-network`, `out_dir` a
  declared TreeArtifact, no shell anywhere in the action (distroless-safe).
- `vitest_test`: hermetic Vitest rule whose executable is a compiled native
  launcher stub (`hermetic_launcher` - the same mechanism rules_pio uses);
  the stub runs node on a staging driver, argv lists throughout, no shell.
- `node_cli`: any npm CLI package as a hermetic executable - native
  stub, node-direct, "$@" passthrough; first consumer is shadcn
  (verified `--help`/`--version` through the stub), shaped for bazel_env
  tool exposure like rules_pio's uv.
- `vite_run`: `bazel run` dev server with NATIVE vite HMR - the real
  workspace tree is served (websocket HMR, React Fast Refresh), with the
  linked node_modules tree symlinked into the workspace for the server's
  lifetime and cleaned up on exit. No ibazel restarts.
- vite is deliberately not vendored: the consumer's `npm_translate_lock`
  provides it, so plugin peer-dependency versions always match the
  application (vite 5/6/7 may coexist in one build graph).
- Examples (vanilla; React with plugin-react + vitest 3) verified
  sandboxed on Bazel 8.7.0 and 9.2.0, macOS arm64.
