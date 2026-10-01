import { createRoot } from "react-dom/client";
import { Badge } from "./components/ui/badge";
import { Button } from "./components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "./components/ui/card";
import { Input } from "./components/ui/input";
import { Label } from "./components/ui/label";

createRoot(document.querySelector("#root")!).render(
  <Card>
    <CardHeader>
      <CardTitle>Lock-pinned shadcn <Badge>new</Badge></CardTitle>
      <CardDescription>Extracted from the registry by the chadcn extension.</CardDescription>
    </CardHeader>
    <CardContent>
      <Label htmlFor="name">Name</Label>
      <Input id="name" placeholder="Your name" />
      <Button>Click me</Button>
    </CardContent>
  </Card>,
);
