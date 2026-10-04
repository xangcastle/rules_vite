import react from "@vitejs/plugin-react";

export default {
  plugins: [react()],
  publicDir: false,
  test: {
    environment: "node",
    include: ["src/**/*.test.js"],
  },
};
