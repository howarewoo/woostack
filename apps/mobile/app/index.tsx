import { useNavigation } from "@infrastructure/navigation";
import * as Linking from "expo-linking";
import { ScrollView, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { UserList } from "@/components/user-list";

const DOCS_URL = "https://github.com/howarewoo/monorepo-template#readme";
const HEADER_TOP_PADDING = 12;

export default function HomeScreen() {
  const insets = useSafeAreaInsets();
  const { navigate } = useNavigation();

  const handleGetStarted = () => {
    navigate("/");
  };

  const handleDocumentation = async () => {
    const supported = await Linking.canOpenURL(DOCS_URL);
    if (supported) {
      await Linking.openURL(DOCS_URL);
    }
  };

  return (
    <View className="flex-1 bg-background">
      <View
        className="bg-background border-b border-border px-4 pb-3"
        style={{ paddingTop: insets.top + HEADER_TOP_PADDING }}
      >
        <Text className="text-lg font-semibold text-foreground">Monorepo Template</Text>
      </View>
      <ScrollView className="flex-1">
        <View className="p-4 gap-6">
          <View className="items-center gap-2">
            <Text className="text-3xl font-bold text-foreground">Monorepo Template</Text>
            <Text className="text-muted-foreground text-center">
              A modern monorepo with Next.js, Expo, Hono, and oRPC
            </Text>
          </View>

          <View className="gap-4">
            <Card>
              <CardHeader>
                <CardTitle>
                  <Text>Next.js</Text>
                </CardTitle>
                <CardDescription>
                  <Text>Web application</Text>
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Text className="text-sm text-muted-foreground">
                  React framework with App Router and shadcn/ui components
                </Text>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>
                  <Text>Expo</Text>
                </CardTitle>
                <CardDescription>
                  <Text>Mobile application</Text>
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Text className="text-sm text-muted-foreground">
                  React Native with Expo Router and UniWind styling
                </Text>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>
                  <Text>Hono + oRPC</Text>
                </CardTitle>
                <CardDescription>
                  <Text>Type-safe API</Text>
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Text className="text-sm text-muted-foreground">
                  End-to-end type safety with oRPC and Hono
                </Text>
              </CardContent>
            </Card>
          </View>

          <Card>
            <CardHeader>
              <CardTitle>
                <Text>Users from API</Text>
              </CardTitle>
              <CardDescription>
                <Text>Data fetched from the Hono API</Text>
              </CardDescription>
            </CardHeader>
            <CardContent>
              <UserList />
            </CardContent>
          </Card>

          <View className="flex-row justify-center gap-4">
            <Button onPress={handleGetStarted}>
              <Text className="text-primary-foreground font-medium">Get Started</Text>
            </Button>
            <Button variant="outline" onPress={handleDocumentation}>
              <Text className="text-foreground font-medium">Documentation</Text>
            </Button>
          </View>
        </View>
      </ScrollView>
    </View>
  );
}
