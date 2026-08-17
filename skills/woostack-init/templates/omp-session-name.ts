import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const reply = (text: string, isError = false) => ({ content: [{ type: "text", text }], isError });
  pi.registerTool({
    name: "woostack_rename_session",
    description: "Rename the active OMP session using a goal-derived title without overwriting explicit user titles.",
    parameters: {
      type: "object",
      properties: { title: { type: "string", description: "Concise single-line title for the active session" } },
      required: ["title"],
    },
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const title = typeof params?.title === "string" ? params.title.trim() : "";
      if (!title || /[\r\n]/.test(title)) return reply("Invalid title: title must be a non-empty single line.", true);
      try {
        const sm = (ctx as Record<string, any>)?.sessionManager ?? pi;
        if (typeof sm?.setSessionName !== "function") return reply("Session rename unavailable: host session manager not found.", true);
        const changed = await sm.setSessionName(title, "auto");
        return reply(changed ? `Session renamed to "${title}".` : "Session name not changed (a user-set name takes precedence).");
      } catch (error) {
        return reply(`Failed to rename session: ${error instanceof Error ? error.message : String(error)}`, true);
      }
    },
  });
}
