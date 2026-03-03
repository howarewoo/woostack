import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { ThemeProvider } from "next-themes";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Brand Kit",
  description: "Design system reference for the monorepo",
};

/**
 * Root layout for the Brand Kit app.
 * Wraps all pages with the next-themes ThemeProvider for flash-free light/dark toggling.
 * suppressHydrationWarning is required on <html> because next-themes modifies the
 * element's class attribute after hydration to apply the resolved theme.
 */
export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
