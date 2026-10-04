import { expect, it } from "vitest";
import { sum } from "./calc.js";

it("compares against the committed snapshot", () => {
  expect({ total: sum([1, 2, 3]) }).toMatchSnapshot();
});

it("never writes a snapshot that was not committed", () => {
  let failure;
  try {
    expect({ committed: false }).toMatchSnapshot("missing on purpose");
  } catch (error) {
    failure = error;
  }
  expect(failure?.message ?? "").toMatch(/snapshot/i);
});
