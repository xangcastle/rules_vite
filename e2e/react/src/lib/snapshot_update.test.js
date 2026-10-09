import { expect, it } from "vitest";
import { increment, sum } from "./calc.js";

it("keeps its committed snapshot in sync with bazel run -u", () => {
  expect({ next: increment(1), total: sum([2, 3]) }).toMatchSnapshot();
});
