/** @type {import('next').NextConfig} */
const frameAncestors =
  "frame-ancestors 'self' https://*.instruqt.com https://play.instruqt.com https://*.instruqt.io";

const nextConfig = {
  reactStrictMode: true,
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [{ key: "Content-Security-Policy", value: frameAncestors }],
      },
    ];
  },
};

export default nextConfig;
