// Decoy: vitest auto-discovers vitest.config.* before vite.config.*. The
// declared_config_test target stages this file next to the declared
// vite.config.ts; config.test.js fails if vitest picked this one instead.
export default {
  test: {
    environment: "node",
    include: ["src/**/*.test.js"],
    env: { RULES_VITE_TEST_CONFIG: "vitest.config.ts (decoy)" },
  },
};
