import react from "@vitejs/plugin-react";

// TypeScript-only syntax on purpose: the dev-server smoke test must prove the
// .ts config is transpiled when vite 6/7 bundle it (they externalize file:// URLs).
const testEnvironment: "node" | "jsdom" = "node";

export default {
  plugins: [react()],
  publicDir: false,
  test: {
    environment: testEnvironment,
    include: ["src/**/*.test.js"],
  },
};
