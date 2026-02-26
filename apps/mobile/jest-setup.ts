/* eslint-disable @typescript-eslint/no-require-imports */

// Mock expo-router
jest.mock("expo-router", () => ({
  useRouter: () => ({
    push: jest.fn(),
    replace: jest.fn(),
    back: jest.fn(),
  }),
  Link: ({ children }: { children: React.ReactNode }) => children,
}));

// Mock expo-constants
jest.mock("expo-constants", () => ({
  __esModule: true,
  default: {
    expoConfig: {
      extra: {
        apiUrl: "http://localhost:3100/api",
      },
    },
  },
}));

// Mock expo-linking
jest.mock("expo-linking", () => ({
  canOpenURL: jest.fn().mockResolvedValue(true),
  openURL: jest.fn().mockResolvedValue(undefined),
}));

// Mock react-native-safe-area-context
jest.mock("react-native-safe-area-context", () => ({
  useSafeAreaInsets: () => ({ top: 0, bottom: 0, left: 0, right: 0 }),
  SafeAreaProvider: ({ children }: { children: React.ReactNode }) => children,
}));

// Mock @infrastructure/navigation
jest.mock("@infrastructure/navigation", () => ({
  useNavigation: () => ({
    navigate: jest.fn(),
    replace: jest.fn(),
    back: jest.fn(),
  }),
  NavigationProvider: ({ children }: { children: React.ReactNode }) => children,
}));
