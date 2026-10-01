import { Activity, CreditCard, Home, Package, Settings, Users } from "lucide-react";
import { Badge } from "../components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Separator } from "../components/ui/separator";
import {
    Sidebar,
    SidebarContent,
    SidebarFooter,
    SidebarGroup,
    SidebarGroupContent,
    SidebarGroupLabel,
    SidebarHeader,
    SidebarMenu,
    SidebarMenuButton,
    SidebarMenuItem,
    SidebarProvider,
    SidebarTrigger,
} from "../components/ui/sidebar";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";
import { Tabs, TabsList, TabsTrigger } from "../components/ui/tabs";

const nav = [
    { title: "Overview", icon: Home },
    { title: "Orders", icon: Package },
    { title: "Customers", icon: Users },
    { title: "Billing", icon: CreditCard },
    { title: "Settings", icon: Settings },
];

const kpis = [
    { label: "Total revenue", value: "$45,231.89", delta: "+20.1% from last month" },
    { label: "Subscriptions", value: "+2,350", delta: "+180.1% from last month" },
    { label: "Sales", value: "+12,234", delta: "+19% from last month" },
    { label: "Active now", value: "573", delta: "+201 since last hour" },
];

const orders = [
    { customer: "Olivia Martin", email: "olivia.martin@email.com", status: "Paid", method: "Credit card" },
    { customer: "Jackson Lee", email: "jackson.lee@email.com", status: "Pending", method: "PayPal" },
    { customer: "Isabella Nguyen", email: "isabella.nguyen@email.com", status: "Paid", method: "Credit card" },
    { customer: "William Kim", email: "will@email.com", status: "Failed", method: "Credit card" },
    { customer: "Sofia Davis", email: "sofia.davis@email.com", status: "Paid", method: "PayPal" },
];

const statusVariant = { Paid: "default", Pending: "secondary", Failed: "destructive" } as const;

export function App() {
    return (
        <SidebarProvider>
            <AppSidebar />
            <main className="flex flex-1 flex-col gap-6 p-6">
                <header className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <SidebarTrigger />
                        <h1 className="text-lg font-semibold">Dashboard</h1>
                    </div>
                    <Tabs defaultValue="30d">
                        <TabsList>
                            <TabsTrigger value="7d">7 days</TabsTrigger>
                            <TabsTrigger value="30d">30 days</TabsTrigger>
                            <TabsTrigger value="90d">90 days</TabsTrigger>
                        </TabsList>
                    </Tabs>
                </header>
                <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                    {kpis.map((kpi) => (
                        <Card key={kpi.label}>
                            <CardHeader>
                                <CardDescription>{kpi.label}</CardDescription>
                                <CardTitle className="text-2xl">{kpi.value}</CardTitle>
                            </CardHeader>
                            <CardContent className="text-muted-foreground text-xs">{kpi.delta}</CardContent>
                        </Card>
                    ))}
                </section>
                <Card>
                    <CardHeader>
                        <CardTitle>Recent orders</CardTitle>
                        <CardDescription>You made 265 sales this month.</CardDescription>
                    </CardHeader>
                    <CardContent>
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Customer</TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead>Method</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {orders.map((order) => (
                                    <TableRow key={order.email}>
                                        <TableCell>
                                            <p className="font-medium">{order.customer}</p>
                                            <p className="text-muted-foreground text-sm">{order.email}</p>
                                        </TableCell>
                                        <TableCell>
                                            <Badge variant={statusVariant[order.status as keyof typeof statusVariant]}>
                                                {order.status}
                                            </Badge>
                                        </TableCell>
                                        <TableCell className="text-muted-foreground">{order.method}</TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    </CardContent>
                </Card>
            </main>
        </SidebarProvider>
    );
}

function AppSidebar() {
    return (
        <Sidebar>
            <SidebarHeader>
                <SidebarMenu>
                    <SidebarMenuItem>
                        <SidebarMenuButton size="lg">
                            <div className="bg-primary text-primary-foreground flex aspect-square size-8 items-center justify-center rounded-lg">
                                <Activity className="size-4" />
                            </div>
                            <div className="flex flex-col leading-none">
                                <span className="font-semibold">Acme Inc</span>
                                <span className="text-muted-foreground text-xs">Enterprise plan</span>
                            </div>
                        </SidebarMenuButton>
                    </SidebarMenuItem>
                </SidebarMenu>
            </SidebarHeader>
            <Separator />
            <SidebarContent>
                <SidebarGroup>
                    <SidebarGroupLabel>Platform</SidebarGroupLabel>
                    <SidebarGroupContent>
                        <SidebarMenu>
                            {nav.map((item) => (
                                <SidebarMenuItem key={item.title}>
                                    <SidebarMenuButton isActive={item.title === "Overview"}>
                                        <item.icon />
                                        <span>{item.title}</span>
                                    </SidebarMenuButton>
                                </SidebarMenuItem>
                            ))}
                        </SidebarMenu>
                    </SidebarGroupContent>
                </SidebarGroup>
            </SidebarContent>
            <SidebarFooter />
        </Sidebar>
    );
}
