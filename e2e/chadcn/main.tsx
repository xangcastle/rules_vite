import { createRoot } from "react-dom/client";
import { Button } from "./components/ui/button.tsx";

createRoot(document.querySelector("#root")!).render(
  <Button>Click me</Button>,
);
