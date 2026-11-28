import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// VITE_* variables are read at build time (docker build --build-arg) and
// inlined into the bundle; they are not read when the container starts.
export default defineConfig({
  plugins: [react()],
  server: { host: '0.0.0.0', port: 3000 },
  preview: { host: '0.0.0.0', port: 3000 },
});
