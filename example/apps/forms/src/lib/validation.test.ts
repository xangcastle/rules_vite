import { describe, expect, it } from "vitest";
import { isValidEmail } from "./validation";

describe("isValidEmail", () => {
    it("accepts plain addresses", () => {
        expect(isValidEmail("abel@example.com")).toBe(true);
    });

    it("rejects missing local part or domain", () => {
        expect(isValidEmail("@example.com")).toBe(false);
        expect(isValidEmail("abel@")).toBe(false);
        expect(isValidEmail("abel@example")).toBe(false);
    });

    it("rejects multiple at signs", () => {
        expect(isValidEmail("a@b@example.com")).toBe(false);
    });

    it("rejects dot-anchored domains", () => {
        expect(isValidEmail("abel@.example.com")).toBe(false);
        expect(isValidEmail("abel@example.com.")).toBe(false);
    });

    it("trims surrounding whitespace", () => {
        expect(isValidEmail("  abel@example.com ")).toBe(true);
    });
});
