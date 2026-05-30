# Embedding the demo video

The README embeds the animated **GIF** (`assets/demo.gif`) because a GIF is the only
demo asset GitHub renders automatically inside a markdown `![](…)` everywhere (README,
mobile, social cards). That GIF is silent.

There is also a **voiced MP4** at `demo-output/output.mp4` (1920×1080, H.264, AAC, ~43s,
~3 MB). GitHub plays an MP4 in a native HTML5 player, but **only** when the file is uploaded
through GitHub's own attachment flow, a `<video src="…repo file…">` tag pointing at a file
committed in the repo does **not** play. So the MP4 is published manually, once, like this:

## Add the native player (optional, manual)

1. Open any **issue, pull request, release, or comment** box on the repo on github.com.
2. **Drag `demo-output/output.mp4` into the box** (or click *attach files* and pick it).
   Wait for the upload to finish, GitHub returns a URL of the form
   `https://github.com/user-attachments/assets/<uuid>`.
3. Copy that `user-attachments` URL.
4. Paste it on its own line **at the top of `README.md`**, just above the GIF embed:

   ```markdown
   https://github.com/user-attachments/assets/<uuid>

   ![aws-cost-audit demo](assets/demo.gif)
   ```

   GitHub auto-expands a bare `user-attachments` video URL into an inline HTML5 player.
   Viewers get the voiced player at the top and the silent GIF as the always-on fallback.
5. You can delete the throwaway issue/PR you used to upload, the attachment URL keeps working.

## Limits and formats (GitHub native player)

- **Size:** 10 MB on free plans, 100 MB on paid plans. Our `output.mp4` is well under 10 MB.
- **Formats:** `.mp4`, `.mov`, `.webm`. Use **H.264** video so it plays in every browser
  (our encode is `libx264` + `yuv420p` + AAC audio).
- The committed GIF needs no upload step, it works the moment the README is pushed.

## Rebuilding the assets

Everything is generated locally from `demo-output/` (gitignored). To rebuild:

1. Author the five scene HTML files in `demo-output/scenes/` (1920×1080, dark, AWS-orange accent).
2. Narration → audio in `demo-output/audio/` (one clip per scene).
3. Screenshot each scene → `demo-output/frames/` with Playwright at 1920×1080.
4. Hold each frame for its scene/audio length, fade, concat with crossfades → `output.mp4`.
5. Down-render `output.mp4` → palette → GIF, optimize with `gifsicle`, copy to `assets/demo.gif`.

> Note on narration: the pipeline targets `edge-tts` (voice `en-US-DavisNeural`). In an
> environment where Microsoft's speech endpoint rejects the token (it closes the synthesis
> turn with WS code 1007), the audio was produced with the offline macOS `say` voice
> **Alex** (the closest built-in male US voice) so the demo stays voiced and reproducible.
