import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

const viteRoot = process.env.BAZEL_VITE_ROOT

// https://vite.dev/config/
export default defineConfig({
  root: viteRoot,
  plugins: [react()],
  resolve: {
    alias: [
      { find: 'react', replacement: path.resolve('./node_modules/react') },
      { find: 'react-dom', replacement: path.resolve('./node_modules/react-dom') },
      { find: '@packages/mybutton', replacement: path.resolve('./packages/mybutton/src') },
    ]
  },
  server: {
    host: '0.0.0.0'
  }
}) 