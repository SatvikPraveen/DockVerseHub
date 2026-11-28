// File Location: labs/lab_02_multi_container_compose/frontend/vite.config.js

import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// VITE_* variables are inlined into the bundle. The dev server reads them
// from the environment when it starts; production builds read them at
// build time (docker build --build-arg VITE_API_URL=...).
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    // Replaces CRA's package.json "proxy": relative /api calls in development
    // are forwarded to the api service on the compose network.
    proxy: { '/api': 'http://api:5000' },
  },
  preview: { host: '0.0.0.0', port: 3000 },
  test: {
    environment: 'jsdom',
    setupFiles: './src/setupTests.js',
  },
});
