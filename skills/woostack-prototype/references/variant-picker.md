# Variant picker

Read when building a multi-variant prototype. The picker is review chrome for switching between
variants: it is not part of any variant's design, a production component, or a reason to touch the
target project. Keep the comparison page, its variants, and checkpoints in the task-owned artifact
workspace.

## Stage one variant at full size

Render one variant at a time, at full size, inside the realistic surroundings it would live in: a
toast over the page it interrupts, a card among its siblings, a control inside its form, a screen
inside its navigation. Keep those surroundings identical across variants so only the decision under
comparison changes. Do not shrink variants into side-by-side thumbnails; scale, density, motion, and
reading order stop being comparable at that size.

Use the same viewport, theme, and synthetic data for every variant. When a size or theme matters to
the decision, review every variant under it rather than splitting conditions between variants.

## Keep the chrome neutral

The picker is a compact floating pill of dark translucent glass with light text, centered at the
bottom of the viewport, labeling each variant with its number and descriptive name. It uses its own
fixed colors, system font, and reset controls, never the project's tokens or component styles, so it
always reads as harness chrome instead of competing with the designs.

When a variant occupies the bottom center, such as a toast, dock, or bottom sheet, set
`data-position="top"` on the picker to move it to the top center. At every reviewed size, check that
the picker does not cover content under review.

## Behavior contract

| Behavior | Contract |
| --- | --- |
| Swap | Selecting a variant shows it instantly, with no transition between variants, so rapid back-and-forth comparison stays direct. Only the pill's active highlight slides, and it stops sliding under `prefers-reduced-motion`. |
| Keyboard | `1` to `N` select a variant. `←` and `→` step to the previous or next variant, wrapping at either end. |
| Replay | Render the replay button, its divider, and the `R` shortcut only when at least one variant has entrance or state motion worth re-triggering. Replay restarts the current variant's motion without changing the selection. |
| Ignored keys | Shortcuts do nothing while focus is in an input, textarea, select, or editable content, while Alt, Control, or Meta is held, or when the variant already handled the key. |
| URL | The current variant's 1-based position is kept in `?v=N` without adding history entries. Reloading or sharing the link reopens that variant; a missing or invalid value opens the first. |
| Semantics | Picker controls are real buttons with a visible focus ring, and the current variant's button has `aria-pressed="true"`. |

Keep variant order fixed within a set so `?v=N` and the shortcuts keep their meaning. A riff is a new
set in its own checkpoint, not a reordering of the previous set. A link alone does not record
approval; approval names the exact set snapshot and variant.

## Reference wiring

Adapt this standalone sketch; it needs no build step or dependency. Give each variant a
`data-variant` attribute holding its name, and add `data-motion` to variants with motion to replay.
Script-driven motion can restart on the `variant:replay` event. A variant that handles arrow or
number keys itself should call `preventDefault()` so the picker leaves those keys alone.

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Order status toast: variants</title>
  <!-- The prototype's own styles go here. -->
  <style>
    /* Harness chrome: fixed neutral values, never project tokens. */
    [data-variant][hidden] { display: none !important; }
    .proto-picker {
      all: initial; position: fixed; z-index: 2147483000; left: 50%;
      bottom: max(16px, env(safe-area-inset-bottom)); transform: translateX(-50%);
      display: flex; align-items: center; gap: 2px; padding: 4px; border-radius: 999px;
      border: 1px solid rgb(255 255 255 / 0.14); background: rgb(20 20 22 / 0.72);
      -webkit-backdrop-filter: blur(14px) saturate(1.4); backdrop-filter: blur(14px) saturate(1.4);
      box-shadow: 0 10px 30px rgb(0 0 0 / 0.28); color: #fff; color-scheme: dark;
      font: 500 13px/1 system-ui, sans-serif;
    }
    .proto-picker[data-position="top"] { bottom: auto; top: max(16px, env(safe-area-inset-top)); }
    .proto-picker button {
      all: unset; position: relative; z-index: 1; box-sizing: border-box; display: inline-flex;
      align-items: center; gap: 6px; min-height: 32px; padding: 0 12px; border-radius: 999px;
      color: rgb(255 255 255 / 0.66); cursor: pointer; white-space: nowrap;
    }
    .proto-picker button:hover, .proto-picker button[aria-pressed="true"] { color: #fff; }
    .proto-picker button:focus-visible { outline: 2px solid #fff; outline-offset: 1px; }
    .proto-picker kbd { all: unset; opacity: 0.6; font-variant-numeric: tabular-nums; }
    .proto-picker__highlight {
      position: absolute; top: 4px; bottom: 4px; left: 0; border-radius: 999px;
      background: rgb(255 255 255 / 0.14);
    }
    .proto-picker[data-ready] .proto-picker__highlight {
      transition: transform 180ms ease-out, width 180ms ease-out;
    }
    .proto-picker__divider { width: 1px; height: 16px; margin: 0 4px; background: rgb(255 255 255 / 0.18); }
    @media (prefers-reduced-motion: reduce) {
      .proto-picker[data-ready] .proto-picker__highlight { transition: none; }
    }
  </style>
</head>
<body>
  <!-- Shared realistic context: the page each toast appears over. -->
  <main class="orders-page">
    <section data-variant="Quiet">…</section>
    <section data-variant="Editorial" hidden>…</section>
    <section data-variant="Dense" data-motion hidden>…</section>
  </main>
  <!-- Add data-position="top" when a variant occupies the bottom center. -->
  <div class="proto-picker" role="group" aria-label="Prototype variants"></div>
  <script>
    (() => {
      const variants = [...document.querySelectorAll("[data-variant]")];
      const picker = document.querySelector(".proto-picker");
      if (!picker || variants.length < 2) return;
      const canReplay = variants.some((variant) => variant.hasAttribute("data-motion"));
      const highlight = document.createElement("span");
      highlight.className = "proto-picker__highlight";
      picker.append(highlight);
      let current = 0;

      const buttons = variants.map((variant, index) => {
        const button = document.createElement("button");
        const key = document.createElement("kbd");
        button.type = "button";
        key.textContent = String(index + 1);
        button.append(key, variant.dataset.variant);
        button.addEventListener("click", () => show(index));
        picker.append(button);
        return button;
      });

      if (canReplay) {
        const divider = document.createElement("span");
        const replayButton = document.createElement("button");
        divider.className = "proto-picker__divider";
        replayButton.type = "button";
        replayButton.textContent = "Replay";
        replayButton.title = "Replay motion (R)";
        replayButton.addEventListener("click", replay);
        picker.append(divider, replayButton);
      }

      function place() {
        const active = buttons[current];
        highlight.style.width = `${active.offsetWidth}px`;
        highlight.style.transform = `translateX(${active.offsetLeft}px)`;
      }

      function show(index) {
        current = index;
        variants.forEach((variant, i) => { variant.hidden = i !== index; });
        buttons.forEach((button, i) => button.setAttribute("aria-pressed", String(i === index)));
        place();
        const url = new URL(location.href);
        url.searchParams.set("v", String(index + 1));
        try { history.replaceState(history.state, "", url); } catch { /* Keep switching if refused. */ }
      }

      function replay() {
        const variant = variants[current];
        variant.hidden = true;
        void variant.offsetWidth; // Flush styles so CSS animations restart when shown again.
        variant.hidden = false;
        variant.dispatchEvent(new CustomEvent("variant:replay"));
      }

      document.addEventListener("keydown", (event) => {
        if (event.defaultPrevented || event.isComposing) return;
        if (event.altKey || event.ctrlKey || event.metaKey) return;
        const editable = "input, textarea, select, [contenteditable]:not([contenteditable='false'])";
        if (event.target instanceof Element && event.target.closest(editable)) return;
        const count = variants.length;
        if (/^[1-9]$/.test(event.key) && Number(event.key) <= count) show(Number(event.key) - 1);
        else if (event.key === "ArrowRight") show((current + 1) % count);
        else if (event.key === "ArrowLeft") show((current - 1 + count) % count);
        else if (canReplay && event.key.toLowerCase() === "r") replay();
        else return;
        event.preventDefault();
      });

      const requested = Number.parseInt(new URLSearchParams(location.search).get("v") ?? "", 10);
      show(requested >= 1 && requested <= variants.length ? requested - 1 : 0);
      addEventListener("resize", place);
      document.fonts?.ready.then(place);
      requestAnimationFrame(() => picker.setAttribute("data-ready", ""));
    })();
  </script>
</body>
</html>
```

Serve the page with the prototype's existing preview. If a browser refuses the URL update, switching
still works, but the address does not keep the selection.

## Check the harness

Before presenting, exercise every number key and both arrows, reload with `?v=N` for a variant other
than the first, use replay when it is present, check the top position when used, and confirm a clean
console. These checks prove only the harness. Each variant still needs its own design verification.
