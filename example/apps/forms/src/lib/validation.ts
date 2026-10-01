export function isValidEmail(value: string): boolean {
    const trimmed = value.trim();
    const at = trimmed.indexOf("@");
    if (at <= 0 || at !== trimmed.lastIndexOf("@")) {
        return false;
    }
    const [local, domain] = trimmed.split("@");
    return local.length > 0 && domain.includes(".") && !domain.startsWith(".") && !domain.endsWith(".");
}
