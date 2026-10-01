import { useState } from "react";
import { Bot, Send, User } from "lucide-react";
import { Avatar, AvatarFallback } from "../components/ui/avatar";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Separator } from "../components/ui/separator";

type Message = { id: number; author: "you" | "agent"; text: string };

const seed: Message[] = [
    { id: 1, author: "agent", text: "Hi! I'm the Acme support agent. How can I help today?" },
    { id: 2, author: "you", text: "I'd like to know when order #1043 ships." },
    { id: 3, author: "agent", text: "It's scheduled to leave the warehouse tomorrow morning. I'll email you the tracking link as soon as it scans in." },
];

export function App() {
    const [messages, setMessages] = useState<Message[]>(seed);
    const [draft, setDraft] = useState("");

    function send() {
        const text = draft.trim();
        if (!text) {
            return;
        }
        setMessages((prev) => [...prev, { id: prev.length + 1, author: "you", text }]);
        setDraft("");
        setTimeout(() => {
            setMessages((prev) => [
                ...prev,
                { id: prev.length + 1, author: "agent", text: `Got it - noted "${text}". Anything else?` },
            ]);
        }, 400);
    }

    return (
        <main className="bg-muted/40 flex min-h-svh flex-col">
            <header className="flex items-center gap-3 p-4">
                <Avatar>
                    <AvatarFallback><Bot /></AvatarFallback>
                </Avatar>
                <div>
                    <p className="text-sm font-semibold">Acme Support</p>
                    <p className="text-muted-foreground text-xs">Typically replies instantly</p>
                </div>
            </header>
            <Separator />
            <section className="flex flex-1 flex-col gap-3 overflow-y-auto p-4">
                {messages.map((m) => (
                    <div key={m.id} className={`flex items-end gap-2 ${m.author === "you" ? "flex-row-reverse" : ""}`}>
                        <Avatar className="size-8">
                            <AvatarFallback>
                                {m.author === "you" ? <User /> : <Bot />}
                            </AvatarFallback>
                        </Avatar>
                        <p
                            className={`max-w-[75%] rounded-2xl px-3 py-2 text-sm ${
                                m.author === "you"
                                    ? "bg-primary text-primary-foreground rounded-br-sm"
                                    : "bg-background border rounded-bl-sm"
                            }`}
                        >
                            {m.text}
                        </p>
                    </div>
                ))}
            </section>
            <footer className="flex gap-2 p-4">
                <Input
                    value={draft}
                    onChange={(e) => setDraft(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && send()}
                    placeholder="Type a message..."
                />
                <Button onClick={send} size="icon">
                    <Send />
                </Button>
            </footer>
        </main>
    );
}
