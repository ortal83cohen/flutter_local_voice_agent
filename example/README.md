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

See the package README for provisioning, permissions, and current limits.
