import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      "/users": { target: "http://localhost:3001", changeOrigin: true },
      "/me":    { target: "http://localhost:3001", changeOrigin: true },
      "/salas": { target: "http://localhost:3001", changeOrigin: true },
      "/lotes": { target: "http://localhost:3001", changeOrigin: true },
      "/health": { target: "http://localhost:3001", changeOrigin: true },
    }
  }
})
