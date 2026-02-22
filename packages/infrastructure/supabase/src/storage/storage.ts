import type { SupabaseClient } from "@supabase/supabase-js";

interface StorageClient {
  /** Upload a file to a Supabase Storage bucket. */
  upload(bucket: string, path: string, file: File | Blob): Promise<{ path: string }>;
  /** Download a file from a Supabase Storage bucket. */
  download(bucket: string, path: string): Promise<Blob>;
  /** Get the public URL for a file in a Supabase Storage bucket. */
  getPublicUrl(bucket: string, path: string): string;
  /** Remove one or more files from a Supabase Storage bucket. */
  remove(bucket: string, paths: string[]): Promise<void>;
}

/** Creates a typed wrapper around Supabase Storage operations. */
export function createStorageClient(supabase: SupabaseClient): StorageClient {
  return {
    async upload(bucket, path, file) {
      const { data, error } = await supabase.storage.from(bucket).upload(path, file);
      if (error) throw error;
      return { path: data.path };
    },

    async download(bucket, path) {
      const { data, error } = await supabase.storage.from(bucket).download(path);
      if (error) throw error;
      return data;
    },

    getPublicUrl(bucket, path) {
      const { data } = supabase.storage.from(bucket).getPublicUrl(path);
      return data.publicUrl;
    },

    async remove(bucket, paths) {
      const { error } = await supabase.storage.from(bucket).remove(paths);
      if (error) throw error;
    },
  };
}
