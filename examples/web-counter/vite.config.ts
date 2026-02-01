import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      // Link to local NativeRPC web SDK for development
      '@token-team/nativerpc-web': path.resolve(__dirname, '../../connections/web/src')
    }
  },
  server: {
    host: true, // Allow access from network (for mobile testing)
    port: 5173
  }
})
