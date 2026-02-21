import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Providers } from "@/app/providers";

const mockNavigationValue = {
  router: {
    navigate: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
  },
  Link: ({ children }: { children: React.ReactNode }) => <>{children}</>,
};

vi.mock("@/lib/navigation", () => ({
  useWebNavigation: () => mockNavigationValue,
}));

vi.mock("@/lib/supabase", () => ({
  createBrowserSupabase: () => ({
    auth: {
      getSession: vi.fn(() => Promise.resolve({ data: { session: null }, error: null })),
      onAuthStateChange: vi.fn(() => ({
        data: { subscription: { unsubscribe: vi.fn() } },
      })),
    },
  }),
}));

const navigationProviderSpy = vi.fn();

vi.mock("@infrastructure/navigation", () => ({
  NavigationProvider: ({ children, value }: { children: React.ReactNode; value: unknown }) => {
    navigationProviderSpy(value);
    return <div data-testid="navigation-provider">{children}</div>;
  },
}));

describe("Providers", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders children wrapped in providers", () => {
    render(
      <Providers>
        <div data-testid="child">Hello</div>
      </Providers>
    );

    expect(screen.getByTestId("child")).toBeDefined();
    expect(screen.getByText("Hello")).toBeDefined();
  });

  it("wraps children with NavigationProvider", () => {
    render(
      <Providers>
        <div data-testid="child">Hello</div>
      </Providers>
    );

    expect(screen.getByTestId("navigation-provider")).toBeDefined();
  });

  it("passes navigation value to NavigationProvider", () => {
    render(
      <Providers>
        <div data-testid="child">Hello</div>
      </Providers>
    );

    expect(navigationProviderSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        router: expect.objectContaining({
          navigate: expect.any(Function),
          replace: expect.any(Function),
          back: expect.any(Function),
        }),
        Link: expect.any(Function),
      })
    );
  });
});
