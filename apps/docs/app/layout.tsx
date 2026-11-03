import { RootProvider } from "fumadocs-ui/provider/next";
import localFont from "next/font/local";
import "./global.css";

const display = localFont({
  src: "./fonts/Archivo.woff2",
  weight: "400",
  style: "normal",
  display: "swap",
  variable: "--font-display",
  fallback: ["Arial Black", "sans-serif"],
});
const sans = localFont({
  src: [
    { path: "./fonts/DM.woff2", weight: "400" },
    { path: "./fonts/DMSemibold.woff2", weight: "600" },
  ],
  display: "swap",
  variable: "--font-body",
  fallback: ["system-ui", "sans-serif"],
});
const mono = localFont({
  src: [
    { path: "./fonts/Plex.woff2", weight: "400" },
    { path: "./fonts/PlexMedium.woff2", weight: "500" },
  ],
  display: "swap",
  variable: "--font-code",
  fallback: ["ui-monospace", "Consolas", "monospace"],
});

export default function Layout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${display.variable} ${sans.variable} ${mono.variable}`}
      suppressHydrationWarning
    >
      <body className="flex flex-col min-h-screen">
        <a className="skip-link" href="#main-content">
          Skip to content
        </a>
        <RootProvider>{children}</RootProvider>
      </body>
    </html>
  );
}
