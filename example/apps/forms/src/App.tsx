import { useState } from "react";
import { Send } from "lucide-react";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Switch } from "../components/ui/switch";
import { Textarea } from "../components/ui/textarea";
import { isValidEmail } from "./lib/validation";

type Errors = { name?: string; email?: string };

export function App() {
    const [name, setName] = useState("");
    const [email, setEmail] = useState("");
    const [role, setRole] = useState("developer");
    const [message, setMessage] = useState("");
    const [notify, setNotify] = useState(true);
    const [errors, setErrors] = useState<Errors>({});
    const [submitted, setSubmitted] = useState<string | null>(null);

    function onSubmit(event: React.FormEvent) {
        event.preventDefault();
        const next: Errors = {};
        if (!name.trim()) {
            next.name = "Name is required.";
        }
        if (!isValidEmail(email)) {
            next.email = "Enter a valid email address.";
        }
        setErrors(next);
        if (Object.keys(next).length === 0) {
            setSubmitted(JSON.stringify({ name, email, role, message, notify }, null, 2));
        }
    }

    return (
        <main className="bg-muted/40 flex min-h-svh items-center justify-center p-6">
            <Card className="w-full max-w-md">
                <CardHeader>
                    <CardTitle>Contact support</CardTitle>
                    <CardDescription>We usually reply within one business day.</CardDescription>
                </CardHeader>
                <form onSubmit={onSubmit} noValidate>
                    <CardContent className="grid gap-4">
                        <div className="grid gap-2">
                            <Label htmlFor="name">Name</Label>
                            <Input id="name" value={name} onChange={(e) => setName(e.target.value)} aria-invalid={!!errors.name} />
                            {errors.name && <p className="text-destructive text-sm">{errors.name}</p>}
                        </div>
                        <div className="grid gap-2">
                            <Label htmlFor="email">Email</Label>
                            <Input id="email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} aria-invalid={!!errors.email} />
                            {errors.email && <p className="text-destructive text-sm">{errors.email}</p>}
                        </div>
                        <div className="grid gap-2">
                            <Label htmlFor="role">Role</Label>
                            <Select value={role} onValueChange={setRole}>
                                <SelectTrigger id="role" className="w-full">
                                    <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="developer">Developer</SelectItem>
                                    <SelectItem value="designer">Designer</SelectItem>
                                    <SelectItem value="manager">Manager</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid gap-2">
                            <Label htmlFor="message">Message</Label>
                            <Textarea id="message" value={message} onChange={(e) => setMessage(e.target.value)} placeholder="What can we help you with?" />
                        </div>
                        <div className="flex items-center justify-between">
                            <Label htmlFor="notify">Email me updates</Label>
                            <Switch id="notify" checked={notify} onCheckedChange={setNotify} />
                        </div>
                    </CardContent>
                    <CardFooter className="mt-4 flex flex-col gap-4">
                        <Button type="submit" className="w-full">
                            Send message <Send />
                        </Button>
                        {submitted && (
                            <pre className="bg-muted w-full overflow-auto rounded-md p-3 text-xs">{submitted}</pre>
                        )}
                    </CardFooter>
                </form>
            </Card>
        </main>
    );
}
