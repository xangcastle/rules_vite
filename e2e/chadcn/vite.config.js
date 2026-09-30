import path from "node:path";

export default {
  publicDir: false,
  resolve: {
    alias: {
      "cn": path.resolve(import.meta.dirname, "cn.ts"),
    },
  },
};
