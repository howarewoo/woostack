/** Options for the security headers middleware. */
export interface SecurityHeadersOptions {
  /** Value for X-Content-Type-Options. Defaults to "nosniff". */
  contentTypeOptions?: string;
  /** Value for X-Frame-Options. Defaults to "DENY". */
  frameOptions?: string;
  /** Value for Strict-Transport-Security. Defaults to "max-age=31536000; includeSubDomains". */
  strictTransportSecurity?: string;
  /** Value for X-XSS-Protection. Defaults to "0" (disabled in favor of CSP). */
  xssProtection?: string;
  /** Value for Referrer-Policy. Defaults to "strict-origin-when-cross-origin". */
  referrerPolicy?: string;
  /** Value for Content-Security-Policy. Defaults to undefined (not set). */
  contentSecurityPolicy?: string;
  /** Value for Permissions-Policy. Defaults to undefined (not set). */
  permissionsPolicy?: string;
}

/** Options for the CSRF protection middleware. */
export interface CsrfProtectionOptions {
  /** List of allowed origins for state-changing requests. */
  allowedOrigins: string[];
}

/** Options for the body limit middleware. */
export interface BodyLimitOptions {
  /** Maximum request body size in bytes. Defaults to 1048576 (1 MB). */
  maxSize?: number;
}
