import react from "@vitejs/plugin-react";

export default {
  plugins: [react()],
  publicDir: false,
  test: {
    environment: "node",
    include: ["src/**/*.test.js"],
    env: { RULES_VITE_TEST_CONFIG: "vite.config.ts" },
  },
};
