import { HelpCircle, MoreHorizontal, Trash2 } from "lucide-react";
import { Avatar, AvatarFallback } from "../components/ui/avatar";
import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "../components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "../components/ui/dropdown-menu";
import { Label } from "../components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Separator } from "../components/ui/separator";
import { Switch } from "../components/ui/switch";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "../components/ui/tooltip";

export function App() {
    return (
        <TooltipProvider>
            <main className="bg-muted/40 mx-auto flex min-h-svh max-w-xl flex-col gap-6 p-6">
                <div className="flex items-center justify-between">
                    <h1 className="text-lg font-semibold">Settings</h1>
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon">
                                <MoreHorizontal />
                                <span className="sr-only">Account actions</span>
                            </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                            <DropdownMenuLabel>Account</DropdownMenuLabel>
                            <DropdownMenuItem>Export data</DropdownMenuItem>
                            <DropdownMenuItem>Manage sessions</DropdownMenuItem>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem variant="destructive" disabled>
                                Delete account
                            </DropdownMenuItem>
                        </DropdownMenuContent>
                    </DropdownMenu>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Profile</CardTitle>
                        <CardDescription>This is how teammates see you.</CardDescription>
                    </CardHeader>
                    <CardContent className="flex items-center gap-4">
                        <Avatar className="size-12">
                            <AvatarFallback>XA</AvatarFallback>
                        </Avatar>
                        <div>
                            <p className="font-medium">Xang Castle</p>
                            <p className="text-muted-foreground text-sm">xang@acme.dev</p>
                        </div>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>Preferences</CardTitle>
                        <CardDescription>Applied to this workspace only.</CardDescription>
                    </CardHeader>
                    <CardContent className="grid gap-5">
                        <div className="flex items-center justify-between">
                            <div className="grid gap-1">
                                <Label htmlFor="theme">Theme</Label>
                                <p className="text-muted-foreground text-sm">Colors follow system by default.</p>
                            </div>
                            <Select defaultValue="system">
                                <SelectTrigger id="theme" className="w-36">
                                    <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="system">System</SelectItem>
                                    <SelectItem value="light">Light</SelectItem>
                                    <SelectItem value="dark">Dark</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>
                        <Separator />
                        <ToggleRow id="digest" label="Weekly digest" hint="A summary of workspace activity." defaultChecked />
                        <Separator />
                        <ToggleRow id="mentions" label="Mention emails" hint="When someone @mentions you." defaultChecked />
                        <Separator />
                        <ToggleRow id="product" label="Product updates" hint="Occasional news about new features." />
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>Danger zone</CardTitle>
                        <CardDescription>Irreversible actions live here.</CardDescription>
                    </CardHeader>
                    <CardContent className="flex items-center justify-between gap-4">
                        <p className="text-muted-foreground text-sm">
                            Permanently remove this workspace and all of its data.
                        </p>
                        <Dialog>
                            <div className="flex items-center gap-2">
                                <Tooltip>
                                    <TooltipTrigger asChild>
                                        <span tabIndex={0}>
                                            <HelpCircle className="text-muted-foreground size-4" />
                                        </span>
                                    </TooltipTrigger>
                                    <TooltipContent>This cannot be undone.</TooltipContent>
                                </Tooltip>
                                <DialogTrigger asChild>
                                    <Button variant="destructive">
                                        <Trash2 /> Delete
                                    </Button>
                                </DialogTrigger>
                            </div>
                            <DialogContent>
                                <DialogHeader>
                                    <DialogTitle>Delete workspace?</DialogTitle>
                                    <DialogDescription>
                                        All applications, deployments and logs will be removed. This action
                                        cannot be undone.
                                    </DialogDescription>
                                </DialogHeader>
                                <DialogFooter>
                                    <DialogClose asChild>
                                        <Button variant="outline">Cancel</Button>
                                    </DialogClose>
                                    <DialogClose asChild>
                                        <Button variant="destructive">Yes, delete everything</Button>
                                    </DialogClose>
                                </DialogFooter>
                            </DialogContent>
                        </Dialog>
                    </CardContent>
                </Card>
            </main>
        </TooltipProvider>
    );
}

function ToggleRow({ id, label, hint, defaultChecked }: { id: string; label: string; hint: string; defaultChecked?: boolean }) {
    return (
        <div className="flex items-center justify-between">
            <div className="grid gap-1">
                <Label htmlFor={id}>{label}</Label>
                <p className="text-muted-foreground text-sm">{hint}</p>
            </div>
            <Switch id={id} defaultChecked={defaultChecked} />
        </div>
    );
}
