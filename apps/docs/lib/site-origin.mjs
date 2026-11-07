const productionOrigin = "https://woostack-docs.adam-nathaniel-woo.workers.dev";

// Build-time only: request headers must not influence prerendered metadata.
export function getSiteOrigin(value = process.env.DOCS_SITE_ORIGIN ?? productionOrigin) {
  const url = new URL(value);
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash ||
    url.hostname === "localhost" ||
    url.hostname.endsWith(".localhost") ||
    url.hostname === "127.0.0.1" ||
    url.hostname === "[::1]"
  ) {
    throw new Error(
      "DOCS_SITE_ORIGIN must be an HTTPS deployment origin without credentials, path, query, or fragment",
    );
  }
  return url;
}
