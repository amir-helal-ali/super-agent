/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  typescript: {
    // تجاهل أخطاء TypeScript أثناء البناء
    ignoreBuildErrors: true,
  },
  eslint: {
    // تجاهل أخطاء ESLint أثناء البناء
    ignoreDuringBuilds: true,
  },
};

module.exports = nextConfig;
