"use client";

import { useQuery } from "@tanstack/react-query";
import { apiClient } from "@/lib/api";

export function UserList() {
  const {
    data: users,
    isLoading,
    error,
  } = useQuery({
    queryKey: ["users"],
    queryFn: () => apiClient.users.list(),
  });

  if (isLoading) {
    return <div className="text-muted-foreground">Loading users...</div>;
  }

  if (error) {
    return (
      <div className="text-destructive">
        Failed to load users. Make sure the API is running on port 3100.
      </div>
    );
  }

  if (!users || users.length === 0) {
    return <div className="text-muted-foreground">No users found.</div>;
  }

  return (
    <div className="space-y-4">
      {users.map((user) => (
        <div key={user.id} className="flex items-center justify-between p-4 border rounded-lg">
          <div>
            <div className="font-medium">{user.name}</div>
            <div className="text-sm text-muted-foreground">{user.email}</div>
          </div>
          <div className="text-sm text-muted-foreground">ID: {user.id}</div>
        </div>
      ))}
    </div>
  );
}
