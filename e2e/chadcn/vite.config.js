import path from "node:path";
import react from "@vitejs/plugin-react";

export default {
  publicDir: false,
  plugins: [react()],
  resolve: {
    alias: {
      "cn": path.resolve(import.meta.dirname, "cn.ts"),
    },
  },
  test: {
    environment: "jsdom",
    include: ["src/**/*.test.tsx"],
  },
};
