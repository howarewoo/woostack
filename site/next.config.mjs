import { createMDX } from 'fumadocs-mdx/next';

const withMDX = createMDX();

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  async redirects() {
    return [
      {
        source: '/docs/concepts/memory',
        destination: '/docs/concepts/context-management',
        permanent: true,
      },
      {
        source: '/docs/skills/woostack-ask',
        destination: '/docs/concepts/utilities',
        permanent: true,
      },
      {
        source: '/docs/skills/woostack-dream',
        destination: '/docs/concepts/context-management',
        permanent: true,
      },
    ];
  },
};

export default withMDX(config);
