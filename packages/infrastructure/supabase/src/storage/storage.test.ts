import { describe, expect, it, vi } from "vitest";
import { createStorageClient } from "./storage";

function createMockSupabase() {
  return {
    storage: {
      from: vi.fn(() => ({
        upload: vi.fn(() => Promise.resolve({ data: { path: "avatars/photo.jpg" }, error: null })),
        download: vi.fn(() => Promise.resolve({ data: new Blob(["test"]), error: null })),
        getPublicUrl: vi.fn(() => ({
          data: {
            publicUrl: "http://localhost:54321/storage/v1/object/public/avatars/photo.jpg",
          },
        })),
        remove: vi.fn(() => Promise.resolve({ data: [], error: null })),
      })),
    },
  };
}

describe("createStorageClient", () => {
  it("uploads a file to the specified bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as any);

    const result = await storage.upload("avatars", "photo.jpg", new Blob(["data"]));

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
    expect(result.path).toBe("avatars/photo.jpg");
  });

  it("downloads a file from the specified bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as any);

    const blob = await storage.download("avatars", "photo.jpg");

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
    expect(blob).toBeInstanceOf(Blob);
  });

  it("returns a public URL for a file", () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as any);

    const url = storage.getPublicUrl("avatars", "photo.jpg");

    expect(url).toContain("avatars/photo.jpg");
  });

  it("removes files from a bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as any);

    await storage.remove("avatars", ["photo.jpg", "old.jpg"]);

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
  });
});
