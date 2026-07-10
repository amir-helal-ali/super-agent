/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  // السماح بالاتصال بخادم Zig عبر Docker
  async rewrites() {
    return [
      {
        source: '/api/agent/:path*',
        destination: `${process.env.ZIG_BACKEND_URL || 'http://127.0.0.1:8080'}/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
