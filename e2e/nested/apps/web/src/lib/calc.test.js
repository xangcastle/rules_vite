import { describe, expect, it } from "vitest";
import { increment, sum } from "./calc.js";

describe("calc", () => {
  it("increments", () => {
    expect(increment(41)).toBe(42);
  });

  it("sums", () => {
    expect(sum([1, 2, 3])).toBe(6);
  });
});
