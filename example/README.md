# Example

A Flutter app that downloads a pinned English speech pack, then runs the
offline voice agent. After **Start**, speak a short English phrase. The demo
replies with fixed local text, not a general-purpose LLM.

From the package root, after native provisioning:

```sh
cd example
flutter run
```

Choose **English compact (INT8)** or **English standard (full precision)**,
review the download size, then tap **Download**. Later launches restore the
installed pack without networking.

On Flutter web the example lists only the compact English pack. Start stays
disabled until that pack validates. Create does not download. Native hosts
keep dart:io storage.

```sh
cd example
flutter build web
```

A browser microphone-to-speaker session is not claimed here.

See the package README for provisioning, permissions, and current limits.
