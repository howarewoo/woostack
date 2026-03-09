import type { MiddlewareHandler } from "hono";
import type { SecurityHeadersOptions } from "./types";

/** Create a Hono middleware that sets common security headers on every response. */
export function securityHeaders(options?: SecurityHeadersOptions): MiddlewareHandler {
  const contentTypeOptions = options?.contentTypeOptions ?? "nosniff";
  const frameOptions = options?.frameOptions ?? "DENY";
  const strictTransportSecurity =
    options?.strictTransportSecurity ?? "max-age=31536000; includeSubDomains";
  const xssProtection = options?.xssProtection ?? "0";
  const referrerPolicy = options?.referrerPolicy ?? "strict-origin-when-cross-origin";
  const contentSecurityPolicy = options?.contentSecurityPolicy;
  const permissionsPolicy = options?.permissionsPolicy;

  return async (c, next) => {
    await next();

    c.header("X-Content-Type-Options", contentTypeOptions);
    c.header("X-Frame-Options", frameOptions);
    c.header("Strict-Transport-Security", strictTransportSecurity);
    c.header("X-XSS-Protection", xssProtection);
    c.header("Referrer-Policy", referrerPolicy);

    if (contentSecurityPolicy) {
      c.header("Content-Security-Policy", contentSecurityPolicy);
    }

    if (permissionsPolicy) {
      c.header("Permissions-Policy", permissionsPolicy);
    }
  };
}
