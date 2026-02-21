import { createSupabaseMiddleware } from "@infrastructure/supabase/middleware/nextjs";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export default createSupabaseMiddleware({
  supabaseUrl,
  supabaseAnonKey,
  protectedRoutes: ["/dashboard", "/settings"],
  loginPath: "/login",
});

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
