# Design System Specification: RedReader

## 1. Overview & Creative North Star: "The Nocturnal Curator"
RedReader is not just a tool; it is a cinematic environment for high-focus consumption. The Creative North Star for this system is **"The Nocturnal Curator."** 

We are moving away from the "app-as-a-utility" look. Instead, we are designing a digital gallery where the content (the document) is the exhibit, and the UI is the sophisticated, dark architecture surrounding it. We achieve this through **Intentional Asymmetry**—placing controls in unexpected but ergonomic locations—and **Tonal Depth**, where the interface feels like it’s carved out of a single block of obsidian rather than built from individual boxes. 

This design system rejects the "standard" web grid. It embraces breathing room, using wide margins and high-contrast typography scales to create an editorial feel that feels premium and lightweight.

---

## 2. Colors & Surface Logic

### The "No-Line" Rule
To achieve a high-end aesthetic, **1px solid borders are prohibited for sectioning.** Boundaries must be defined solely through background color shifts. For example, a sidebar using `surface-container-low` sits directly against the `surface` background of the main viewer. This creates a "molded" look rather than a "constructed" one.

### Surface Hierarchy & Nesting
Think of the UI as physical layers of smoked glass and matte paper.
- **Base Layer:** `surface` (#131313) or `surface-container-lowest` (#0E0E0E) for the primary application background.
- **Nesting:** Place a `surface-container-low` (#1C1B1B) section on top of the base to define a secondary area (like a library grid). 
- **Active Focus:** Use `surface-bright` (#3A3939) only for elements that require immediate physical prominence, like a hovering context menu.

### The "Glass & Gradient" Rule
Flat colors can feel sterile. For floating elements (modals, top navigation bars during scroll), use **Glassmorphism**:
- **Token:** `surface` at 80% opacity with a `24px` backdrop-blur.
- **Signature Accent:** For primary CTAs or the "Active Reading" state, use a subtle linear gradient: `primary-container` (#E50914) to a slightly deeper shade. This adds "soul" and visual weight to the red accent without it feeling like a flat, digital "error" color.

---

## 3. Typography: Editorial Precision
We use a dual-typeface system to balance futuristic tech with readable sophistication.

- **Display & Headlines (Space Grotesk):** This is our "mechanical" voice. It’s geometric and wide. Use `display-lg` for empty states and `headline-sm` for library categories. The intentional width of Space Grotesk provides that "slightly futuristic" edge requested in the brief.
- **Body & Labels (Manrope):** This is our "humanist" voice. It is highly legible and elegant. Use `body-md` for metadata (author names, page counts) and `label-sm` for technical data (file size, date modified).

**Hierarchy Strategy:** Create "Typographic Anchors." Pair a large `headline-lg` title with a tiny `label-md` uppercase subtitle. The massive jump in scale creates a luxury editorial feel.

---

## 4. Elevation & Depth

### The Layering Principle
Forget shadows for standard cards. Depth is achieved by "stacking" the `surface-container` tiers.
- **Example:** In the PDF library, the background is `surface-container-low`. The PDF thumbnails sit on `surface-container-high`. The contrast in grey values provides enough "lift" without visual clutter.

### Ambient Shadows
When a "floating" effect is required (e.g., a floating action button or a detached toolbar):
- **Blur:** 32px to 64px.
- **Opacity:** 4% to 8%.
- **Color:** Use a tinted version of `on-surface` (#E5E2E1) rather than pure black. This mimics natural light reflecting off a dark surface.

### The "Ghost Border"
If a boundary is absolutely necessary for accessibility:
- **Token:** `outline-variant` at **15% opacity**. It should be felt, not seen. Explicitly forbid 100% opaque borders.

---

## 5. Components

### The PDF Canvas (The "Exhibit")
- **Background:** `surface-container-lowest`.
- **Shadow:** Use a large, soft `ambient shadow` behind the PDF page to make it appear as if it's floating in a dark room.
- **Corner Radius:** `none` or `sm` (0.25rem) for the document itself to maintain the "paper" feel, while the UI surrounding it uses `lg` (1rem).

### Primary Buttons (Red Accents)
- **Shape:** `full` (pill-shaped) for a modern, friendly touch.
- **Color:** `primary-container` (#E50914).
- **Interaction:** On hover, do not just change brightness; add a `4px` glow (drop-shadow) using the `primary` color at 30% opacity to create a "neon" futuristic pulse.

### Navigation & Sidebar
- **Layout:** Use asymmetric spacing. The left sidebar should have a wider top-padding (`xl`) than the side-padding (`md`) to create a gallery-label effect.
- **Dividers:** **Forbid the use of divider lines.** Use vertical white space (from the spacing scale) or a 1-step shift in `surface-container` color.

### Input Fields & Search
- **Style:** "Bottom-line only" or "Filled" using `surface-container-highest`.
- **Corner Radius:** `md` (0.75rem) on the top corners only, or `full` for a search bar.
- **State:** When focused, the `outline` should glow subtly with the `primary` red at 20% opacity.

---

## 6. Do’s and Don'ts

### Do:
- **Do** use `surface-container` tiers to create hierarchy.
- **Do** use `Space Grotesk` for numbers and file extensions to lean into the futuristic vibe.
- **Do** embrace "Empty Space." If a screen feels cluttered, increase the padding rather than adding a border.
- **Do** ensure the `accent red` is used sparingly—only for primary actions and critical status updates.

### Don’t:
- **Don’t** use pure white (#FFFFFF) for text. Use `on-surface` (#E5E2E1) to reduce eye strain in the dark-only theme.
- **Don’t** use standard 1px borders to separate list items. Use a 4px gap or a tonal shift.
- **Don’t** use sharp corners for UI containers. Stick to the `lg` (1rem) or `xl` (1.5rem) tokens to keep the "Modern/Minimal" promise.
- **Don’t** use heavy drop shadows. If you can clearly see where the shadow ends, it’s too dark.

---

## 7. Spacing Scale
Maintain a strict **8px rhythmic grid**.
- **Small (sm):** 8px (Inner component spacing)
- **Medium (md):** 16px (Element-to-element spacing)
- **Large (lg):** 32px (Section-to-section spacing)
- **Extra Large (xl):** 64px (Page margins and Hero headers)

By following these rules, RedReader will transcend the typical utility app and become a signature, high-end digital experience that feels both lightweight and authoritative.