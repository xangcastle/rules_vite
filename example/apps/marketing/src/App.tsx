import { BarChart3, Lock, LogIn, Zap } from "lucide-react";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "../components/ui/accordion";
import { Badge } from "../components/ui/badge";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Separator } from "../components/ui/separator";

const features = [
    {
        icon: Zap,
        title: "Instant builds",
        description: "Hermetic, sandboxed and cached - rebuild only what changed.",
    },
    {
        icon: Lock,
        title: "Reproducible",
        description: "Every artifact traces back to a pinned lockfile revision.",
    },
    {
        icon: BarChart3,
        title: "Scales out",
        description: "The same action graph runs on your laptop and on the remote cluster.",
    },
];

const faqs = [
    {
        q: "Does this work with my existing vite config?",
        a: "Yes - the config file is staged alongside your sources and passed explicitly, so plugins, aliases and environment flags behave exactly as before.",
    },
    {
        q: "How are dependencies resolved?",
        a: "From the pnpm lockfile through npm_translate_lock. Each build action receives per-package node_modules links carrying only the closures it declared.",
    },
    {
        q: "Can teams share UI components?",
        a: "One component set is injected into every application at build time, so five apps render from a single source of truth without vendoring per app.",
    },
];

export function App() {
    return (
        <main className="flex min-h-svh flex-col">
            <header className="flex items-center justify-between p-6">
                <span className="text-lg font-semibold">acme</span>
                <nav className="hidden gap-6 text-sm sm:flex">
                    <a className="hover:underline" href="#features">Features</a>
                    <a className="hover:underline" href="#faq">FAQ</a>
                </nav>
                <Button variant="outline" size="sm">
                    <LogIn /> Sign in
                </Button>
            </header>
            <section className="mx-auto flex max-w-3xl flex-col items-center gap-5 px-6 py-20 text-center">
                <Badge variant="secondary">v2 now generally available</Badge>
                <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
                    Ship your frontend like your backend
                </h1>
                <p className="text-muted-foreground max-w-xl text-lg">
                    The same hermetic build system for every language in your monorepo - now including vite.
                </p>
                <div className="flex gap-3">
                    <Button size="lg">Get started</Button>
                    <Button size="lg" variant="outline">Book a demo</Button>
                </div>
            </section>
            <Separator />
            <section id="features" className="mx-auto grid max-w-4xl gap-4 px-6 py-16 sm:grid-cols-3">
                {features.map((f) => (
                    <Card key={f.title}>
                        <CardHeader>
                            <f.icon className="text-muted-foreground size-5" />
                            <CardTitle className="mt-2 text-base">{f.title}</CardTitle>
                            <CardDescription>{f.description}</CardDescription>
                        </CardHeader>
                        <CardContent />
                    </Card>
                ))}
            </section>
            <section id="faq" className="mx-auto w-full max-w-xl px-6 pb-20">
                <h2 className="mb-4 text-center text-2xl font-semibold">Frequently asked</h2>
                <Accordion type="single" collapsible>
                    {faqs.map((faq) => (
                        <AccordionItem key={faq.q} value={faq.q}>
                            <AccordionTrigger>{faq.q}</AccordionTrigger>
                            <AccordionContent>{faq.a}</AccordionContent>
                        </AccordionItem>
                    ))}
                </Accordion>
            </section>
            <footer className="text-muted-foreground border-t p-6 text-center text-sm">
                Built with rules_vite - a Bazel ruleset for vite and vitest.
            </footer>
        </main>
    );
}
