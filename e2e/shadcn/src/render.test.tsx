import { createRoot } from "react-dom/client";
import { describe, expect, it } from "vitest";
import { Badge } from "../components/ui/badge";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";

describe("injected shadcn components", () => {
  it("render into the dom", async () => {
    const host = document.createElement("div");
    document.body.appendChild(host);
    createRoot(host).render(
      <Card>
        <CardHeader><CardTitle>Card title</CardTitle></CardHeader>
        <CardContent>
          <Label htmlFor="name">Name</Label>
          <Input id="name" placeholder="Name" />
          <Button>Click me</Button>
          <Badge>Badge</Badge>
        </CardContent>
      </Card>,
    );
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(host.textContent).toContain("Click me");
  });
});
