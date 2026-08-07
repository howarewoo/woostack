import { docs } from 'collections/server';
import { loader } from 'fumadocs-core/source';
import { lucideIconsPlugin } from 'fumadocs-core/source/lucide-icons';
import { docsContentRoute, docsImageRoute, docsRoute } from './shared';

const retiredPagePaths: Record<string, true> = {
  'concepts/engineer-agents.mdx': true,
  'harnesses/hermes.mdx': true,
};
const docsSource = docs.toFumadocsSource();

// WOO-167 deletes these retained files. Until then, exclude them from every route and aggregate
// backed by this source; removing navigation entries alone does not make a page unreachable.
export const source = loader({
  baseUrl: docsRoute,
  source: {
    files: docsSource.files.filter(
      (file) => file.type !== 'page' || retiredPagePaths[file.path] !== true,
    ),
  },
  plugins: [lucideIconsPlugin()],
});

export function getPageImage(page: (typeof source)['$inferPage']) {
  const segments = [...page.slugs, 'image.png'];

  return {
    segments,
    url: `${docsImageRoute}/${segments.join('/')}`,
  };
}

export function getPageMarkdownUrl(page: (typeof source)['$inferPage']) {
  const segments = [...page.slugs, 'content.md'];

  return {
    segments,
    url: `${docsContentRoute}/${segments.join('/')}`,
  };
}

export async function getLLMText(page: (typeof source)['$inferPage']) {
  const processed = await page.data.getText('processed');

  return `# ${page.data.title} (${page.url})

${processed}`;
}
