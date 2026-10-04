import { defineConfig, defineDocs } from 'fumadocs-mdx/config';

// Frontmatter and `meta.json` validation stays on the fumadocs-mdx defaults; only the site
// specific collection options are declared here.
export const docs = defineDocs({
  dir: 'content/docs',
  docs: {
    postprocess: {
      includeProcessedMarkdown: true,
    },
  },
});

export default defineConfig({});