import { createSupabaseMiddleware } from "@infrastructure/supabase/middleware/nextjs";

export default createSupabaseMiddleware({
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL!,
  supabaseAnonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  protectedRoutes: ["/dashboard", "/settings"],
  loginPath: "/login",
});

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
