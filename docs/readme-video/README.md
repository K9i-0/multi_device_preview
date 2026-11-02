# README video

The demo video for the repository README, made with
[Remotion](https://www.remotion.dev/) from a screen recording of the example.

```sh
npm install
# 1. Record (macOS, example running): see the header of scripts/record.sh
# 2. Preview / render the 1080p master
npm run studio
npm run render          # out/readme-master.mp4
# 3. Compress for GitHub (keep it well under 10 MB)
npm run encode          # out/multi_device_preview.mp4, CRF=24 by default
```

- `src/edit-manifest.json` is the timeline: every event is a frame of the
  recording (30 fps); `toComp()` maps it onto the composition.
- Captions are burned in (English). The video has no audio track.
- GitHub only plays videos uploaded as attachments: drag
  `out/multi_device_preview.mp4` into the README editor on github.com and keep
  the `https://github.com/user-attachments/assets/...` line it inserts.
