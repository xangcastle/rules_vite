export default {
  test: {
    environment: "node",
    include: ["src/**/*.test.js"],
    env: { RULES_VITE_TEST_CONFIG: "vitest.config.ts (decoy)" },
  },
};
