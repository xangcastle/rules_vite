import { useState } from "react";
import { increment } from "./lib/calc.js";

export function App() {
  const [count, setCount] = useState(0);
  return (
    <button onClick={() => setCount(increment(count))}>
      counted {count} times
    </button>
  );
}
