# `vite_binary` Bazel Rule

This directory contains a custom Bazel rule, `vite_binary`, for running Vite-based projects within a Bazel workspace. It provides a seamless development experience, including hot-reloading (HMR), while leveraging Bazel's dependency management and build caching.

## Features

- **Hot-Module Reloading (HMR)**: Changes to source files are reflected instantly in the browser without needing to restart the development server.
- **Custom Vite Configuration**: Use your own `vite.config.ts` or `.mjs` file to add plugins, define aliases, and customize Vite to your needs.
- **Automatic Configuration**: For simple projects without a custom config, the rule generates a basic configuration on the fly.
- **Node.js Dependency Management**: Integrates with Bazel's `node_modules` ecosystem, allowing you to specify dependencies for your Vite project.
- **TypeScript and React Support**: Handles TypeScript and React projects out of the box, including JSX/TSX files.

## `vite_binary` API

| Attribute     | Type         | Description                                                                                                                                                                              |
| ------------- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`        | `string`     | **Required.** A unique name for this target.                                                                                                                                             |
| `srcs`        | `label_list` | **Required.** A list of source files for the application. Use `glob` to include all necessary files (`.js`, `.jsx`, `.ts`, `.tsx`, `.css`, `.html`, `public/**`, `tsconfig.json`, etc.). |
| `deps`        | `label_list` | **Optional.** A list of `node_modules` dependencies required by the project. These should be Bazel labels pointing to the specific packages (e.g., `//:node_modules/react`).             |
| `vite_config` | `label`      | **Optional.** A label pointing to a custom `vite.config.ts` or `vite.config.mjs` file. If not provided, a default configuration will be generated.                                       |

## Usage Examples

Below are examples of how to use `vite_binary` for different types of projects.

### 1. Simple TypeScript Project

For a vanilla TypeScript project, you only need to specify the source files. The rule will automatically generate the necessary Vite configuration.

**`//tools/vite/examples/vanillats/BUILD.bazel`**

```bazel
load("//tools/vite:defs.bzl", "vite_binary")

vite_binary(
    name = "dev",
    srcs = glob([
        "src/**",
        "public/**",
        "index.html",
        "tsconfig.json",
    ]),
)
```

### 2. React + TypeScript Project

For a more complex project using React and a custom Vite configuration, you must provide both the `vite_config` file and the necessary `deps`.

**`//tools/vite/examples/reactts/BUILD.bazel`**

```bazel
load("//tools/vite:defs.bzl", "vite_binary")

vite_binary(
    name = "dev",
    srcs = glob([
        "src/**",
        "public/**",
        "index.html",
        "tsconfig.json",
    ]),
    vite_config = "vite.config.mjs",
    deps = [
        "//:node_modules/react",
        "//:node_modules/react-dom",
        "//:node_modules/@vitejs/plugin-react",
        "//:node_modules/@types/react",
        "//:node_modules/@types/react-dom",
    ],
)
```

### Important: Custom `vite.config.mts`

When using a custom configuration (`vite.config.mts` or `.ts`), it's crucial to configure it correctly to work within the Bazel environment.

- **Use `.mts` or `.mjs`**: To ensure your config is treated as an ES Module, especially when importing ESM-only plugins like `@tailwindcss/vite`.
- **Set the `root`**: The configuration must read the `BAZEL_VITE_ROOT` environment variable provided by the rule to set Vite's `root` directory.
- **Define Aliases for Dependencies**: For robust module resolution, define aliases for your key dependencies like `react` and `react-dom`.

Here is a well-structured example for a React + TypeScript + Tailwind CSS project:

**`vite.config.mts`**

```typescript
import path from "path";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import { fileURLToPath } from "url";

// --- Bazel Integration Point #1: ES Module Compatibility ---
// These lines are necessary to define `__dirname` in an ES Module context.
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// --- Bazel Integration Point #2: Root Directory ---
// The `vite_binary` rule provides this environment variable to tell Vite
// where the project's source files are located.
const viteRoot = process.env.BAZEL_VITE_ROOT || __dirname;

export default defineConfig({
  // Tell Vite where to find the `index.html` and source code.
  root: viteRoot,
  plugins: [react(), tailwindcss()],
  resolve: {
    // --- Bazel Integration Point #3: Dependency Resolution ---
    // These aliases ensure that Vite can find your dependencies within
    // Bazel's `runfiles` environment.
    alias: [
      { find: "react", replacement: path.resolve("./node_modules/react") },
      {
        find: "react-dom",
        replacement: path.resolve("./node_modules/react-dom"),
      },
      // Add other critical dependencies here if needed.
    ],
  },
  server: {
    // Expose the server to the network, useful for Docker or VMs.
    host: "0.0.0.0",
  },
});
```

# `vite_test` Bazel Rule

This directory also contains a `vite_test` rule for running tests with Vitest, the testing framework built on top of Vite. It integrates Vitest into the Bazel ecosystem, allowing you to run fast, component-level tests.

## Features

- **Seamless Vitest Integration**: Runs `vitest run` in a sandboxed environment.
- **Automatic Discovery**: Correctly discovers test files (`.test.ts`, `.spec.tsx`, etc.) and configuration files (`vitest.config.mjs`) by setting the test root directory.
- **Dependency Management**: Leverages Bazel's dependency graph to ensure all necessary source files, assets, and `node_modules` are available to the test.

## `vite_test` API

| Attribute     | Type         | Description                                                                                                                                                                                                                                                       |
| ------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`        | `string`     | **Required.** A unique name for this test target.                                                                                                                                                                                                                 |
| `srcs`        | `label_list` | **Required.** A list of all files required for the test. This is critical and must include test files, component source files, CSS, SVGs, and all `tsconfig.json` files (`tsconfig.json`, `tsconfig.app.json`, `tsconfig.node.json`). Use `glob` to capture them. |
| `deps`        | `label_list` | **Optional.** A list of `node_modules` dependencies (e.g., `//:node_modules/@testing-library/react`).                                                                                                                                                             |
| `vite_config` | `label`      | **Required.** A label pointing to your `vitest.config.mjs` file. While the rule finds this by convention, making it explicit ensures Bazel tracks it as a dependency.                                                                                             |

## Usage Example

Here is a complete example of setting up a test for a React + TypeScript component.

**`//tools/vite/examples/reactts/BUILD.bazel`**

```bazel
load("//tools/vite:defs.bzl", "vite_test")

vite_test(
    name = "test",
    srcs = glob(
        [
            "src/**/*",
            "public/*",
        ],
    ) + [
        "tsconfig.json",
        "tsconfig.app.json",
        "tsconfig.node.json",
    ],
    vite_config = "vitest.config.mjs",
    deps = [
        "//:node_modules/@testing-library/jest-dom",
        "//:node_modules/@testing-library/react",
        "//:node_modules/jsdom",
        "//:node_modules/vitest",
    ],
)
```

### Important: `vitest.config.mjs`

For tests to run correctly, your Vitest configuration must be set up to work within the testing environment.

**`vitest.config.mjs`**

```typescript
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  test: {
    // --- Bazel Integration Point: Test Environment ---
    // Use 'jsdom' to simulate a browser environment for React component testing.
    environment: "jsdom",
    // --- Bazel Integration Point: Test Setup ---
    // A setup file to extend Jest's matchers, e.g., for `toBeInTheDocument`.
    setupFiles: ["./src/test/setup.ts"],
  },
});
```
