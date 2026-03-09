import type { Span, Tracer } from "@opentelemetry/api";
import { SpanStatusCode, trace } from "@opentelemetry/api";

const DEFAULT_TRACER_NAME = "app";

/**
 * Returns an OpenTelemetry Tracer instance.
 *
 * When an OTel SDK is configured the returned tracer records real spans;
 * otherwise it returns a no-op tracer (safe to call without setup).
 */
export function getTracer(name: string = DEFAULT_TRACER_NAME): Tracer {
  return trace.getTracer(name);
}

/**
 * Wraps an async function in an OpenTelemetry span.
 *
 * If the function throws, the exception is recorded on the span
 * and the span status is set to ERROR before the error is re-thrown.
 */
export async function withSpan<T>(name: string, fn: (span: Span) => Promise<T>): Promise<T> {
  const tracer = getTracer();
  return tracer.startActiveSpan(name, async (span) => {
    try {
      const result = await fn(span);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.setStatus({ code: SpanStatusCode.ERROR });
      if (error instanceof Error) {
        span.recordException(error);
      }
      throw error;
    } finally {
      span.end();
    }
  });
}
