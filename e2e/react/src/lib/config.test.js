import { expect, it } from "vitest";

it("runs with the config declared in BUILD", () => {
  expect(process.env.RULES_VITE_TEST_CONFIG).toBe("vite.config.ts");
});
