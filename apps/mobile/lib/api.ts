import { createTypedApiClient, createTypedOrpcUtils } from "@infrastructure/api-client";
import Constants from "expo-constants";

const API_URL = Constants.expoConfig?.extra?.apiUrl || "http://localhost:3100/api";

export const apiClient = createTypedApiClient(API_URL);
export const orpc = createTypedOrpcUtils(apiClient);
