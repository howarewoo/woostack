import { useQuery } from "@tanstack/react-query";
import { Text, View } from "react-native";
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
    return <Text className="text-muted-foreground">Loading users...</Text>;
  }

  if (error) {
    return (
      <Text className="text-destructive">
        Failed to load users. Make sure the API is running on port 3100.
      </Text>
    );
  }

  if (!users || users.length === 0) {
    return <Text className="text-muted-foreground">No users found.</Text>;
  }

  return (
    <View className="gap-4">
      {users.map((user) => (
        <View
          key={user.id}
          className="flex-row items-center justify-between p-4 border border-border rounded-lg"
        >
          <View>
            <Text className="font-medium text-foreground">{user.name}</Text>
            <Text className="text-sm text-muted-foreground">{user.email}</Text>
          </View>
          <Text className="text-sm text-muted-foreground">ID: {user.id}</Text>
        </View>
      ))}
    </View>
  );
}
