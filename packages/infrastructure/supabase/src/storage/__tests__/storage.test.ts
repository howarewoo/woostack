import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { createStorageClient } from "../storage";

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

function createMockErrorSupabase() {
  return {
    storage: {
      from: vi.fn(() => ({
        upload: vi.fn(() => Promise.resolve({ data: null, error: new Error("Upload failed") })),
        download: vi.fn(() => Promise.resolve({ data: null, error: new Error("Download failed") })),
        getPublicUrl: vi.fn(() => ({
          data: { publicUrl: "" },
        })),
        remove: vi.fn(() => Promise.resolve({ data: null, error: new Error("Remove failed") })),
      })),
    },
  };
}

describe("createStorageClient", () => {
  it("uploads a file to the specified bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as unknown as SupabaseClient);

    const result = await storage.upload("avatars", "photo.jpg", new Blob(["data"]));

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
    expect(result.path).toBe("avatars/photo.jpg");
  });

  it("downloads a file from the specified bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as unknown as SupabaseClient);

    const blob = await storage.download("avatars", "photo.jpg");

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
    expect(blob).toBeInstanceOf(Blob);
  });

  it("returns a public URL for a file", () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as unknown as SupabaseClient);

    const url = storage.getPublicUrl("avatars", "photo.jpg");

    expect(url).toContain("avatars/photo.jpg");
  });

  it("removes files from a bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as unknown as SupabaseClient);

    await storage.remove("avatars", ["photo.jpg", "old.jpg"]);

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
  });

  it("throws on upload error", async () => {
    const mockSupabase = createMockErrorSupabase();
    const storage = createStorageClient(mockSupabase as unknown as SupabaseClient);

    await expect(storage.upload("avatars", "photo.jpg", new Blob(["data"]))).rejects.toThrow(
      "Upload failed"
    );
  });

  it("throws on download error", async () => {
    const mockSupabase = createMockErrorSupabase();
    const storage = createStorageClient(mockSupabase as unknown as SupabaseClient);

    await expect(storage.download("avatars", "photo.jpg")).rejects.toThrow("Download failed");
  });

  it("throws on remove error", async () => {
    const mockSupabase = createMockErrorSupabase();
    const storage = createStorageClient(mockSupabase as unknown as SupabaseClient);

    await expect(storage.remove("avatars", ["photo.jpg"])).rejects.toThrow("Remove failed");
  });
});
