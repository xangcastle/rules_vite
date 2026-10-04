import { expect, it } from "vitest";

it("fails on a known line so CI can check where the annotation points", () => {
  expect(1 + 1).toBe(3);
});
