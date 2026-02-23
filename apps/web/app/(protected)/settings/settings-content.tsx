"use client";

import { Link } from "@infrastructure/navigation";
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@infrastructure/ui-web";
import { useSignOut } from "@/hooks/use-sign-out";

interface SettingsContentProps {
  email: string;
  userId: string;
  createdAt: string | null;
}

/** Client-side settings content displaying user profile and account actions. */
export function SettingsContent({ email, userId, createdAt }: SettingsContentProps) {
  const handleSignOut = useSignOut();

  return (
    <main className="min-h-screen p-8">
      <div className="mx-auto max-w-2xl space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Settings</h1>
            <Link href="/dashboard" className="text-sm text-muted-foreground hover:text-foreground">
              &larr; Dashboard
            </Link>
          </div>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Profile</CardTitle>
            <CardDescription>Your account information</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <span className="text-sm font-medium">Email</span>
              <p className="text-sm text-muted-foreground">{email}</p>
            </div>
            <div>
              <span className="text-sm font-medium">User ID</span>
              <p className="text-sm text-muted-foreground">{userId}</p>
            </div>
            {createdAt && (
              <div>
                <span className="text-sm font-medium">Member since</span>
                <p className="text-sm text-muted-foreground">
                  {new Date(createdAt).toLocaleDateString()}
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Account</CardTitle>
          </CardHeader>
          <CardContent>
            <Button variant="destructive" onClick={handleSignOut}>
              Sign Out
            </Button>
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
