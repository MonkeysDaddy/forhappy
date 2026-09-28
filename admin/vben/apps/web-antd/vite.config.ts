import { defineConfig } from '@vben/vite-config';

export default defineConfig(async () => {
  return {
    application: {},
    vite: {
      server: {
        proxy: {
          // ForHappy 后端（保留 /api 前缀直转 8080）
          '/api': {
            changeOrigin: true,
            target: 'http://localhost:8080',
            ws: true,
          },
        },
      },
    },
  };
});
