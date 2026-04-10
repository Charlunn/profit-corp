import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { createMiddlewareClient } from "@supabase/auth-helpers-nextjs";

// ---------------------------------------------------------------------------
// Auth Middleware — shared/library/auth/middleware_auth.ts
// Route protection for Next.js apps built on Profit-Corp.
// Place this in your app's middleware.ts and configure the `protectedRoutes`
// array to match your dashboard paths.
// ---------------------------------------------------------------------------

/** Routes that require an authenticated session. */
const PROTECTED_ROUTES = ["/dashboard", "/app", "/settings", "/billing"];

/** Routes accessible only when logged OUT (redirect if already authed). */
const AUTH_ROUTES = ["/login", "/signup"];

export async function middleware(req: NextRequest) {
  const res = NextResponse.next();
  const supabase = createMiddlewareClient({ req, res });

  const {
    data: { session },
  } = await supabase.auth.getSession();

  const { pathname } = req.nextUrl;

  // Protect dashboard routes — redirect unauthenticated users to /login
  if (PROTECTED_ROUTES.some((r) => pathname.startsWith(r))) {
    if (!session) {
      const loginUrl = req.nextUrl.clone();
      loginUrl.pathname = "/login";
      loginUrl.searchParams.set("next", pathname);
      return NextResponse.redirect(loginUrl);
    }
  }

  // Redirect already-authenticated users away from auth pages
  if (AUTH_ROUTES.some((r) => pathname.startsWith(r)) && session) {
    const dashUrl = req.nextUrl.clone();
    dashUrl.pathname = "/dashboard";
    return NextResponse.redirect(dashUrl);
  }

  return res;
}

export const config = {
  // Apply middleware to all routes except static assets and API routes
  matcher: ["/((?!_next/static|_next/image|favicon.ico|api/).*)"],
};
