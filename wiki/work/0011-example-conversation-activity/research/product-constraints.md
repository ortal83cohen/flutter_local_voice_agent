# Product constraints for example activity

## Question

What must the example keep saying and doing so a clearer conversation activity display stays honest and inside the current product contract?

Scope is the example conversation status copy and controls only. Hebrew, new languages, speaker names, barge-in, pub.dev packaging, public API changes and the README issue-link fix are out of scope.

## Answer

The example must keep presenting itself as an English-only, half-duplex, foreground, fixed-rule demo. Any new activity wording must describe only what the app can observe in a turn-taking cycle (idle, listening, hearing speech, replying, stopped, suspended or failed). It must not imply a general chat model, simultaneous listening while a reply plays, barge-in by speech, background or wake-word operation, measured audio or voice quality, physical-device qualification, or named speakers. The three explicit controls (Start, Interrupt, Stop) and the Start gating must keep their current meaning. Activity text must stay English and must not contradict the existing "Listening pauses while a reply plays" sentence.

## Findings

### Half duplex is the documented default; full duplex and speech barge-in are unsupported

- Claim: Speech admission pauses during a response. Full duplex and speech barge-in are unsupported and no echo-cancellation qualification is claimed.
- Evidence: The capability table lists "Half duplex | Foreground default; speech admission pauses during response" and "Full duplex / speech barge-in | Unsupported; no AEC qualification claimed". The README platform table repeats "Full duplex / barge-in | Unsupported". Capabilities also states the SDK does not assume simultaneous microphone and speaker operation proves echo cancellation.
- Source: doc/capabilities.md:20-21, doc/capabilities.md:40, README.md:61

### The example already tells the user listening pauses during a reply

- Claim: The example intro already states "Listening pauses while a reply plays." Activity copy must stay consistent with it.
- Evidence: The sentence is in the introductory paragraph above the model picker.
- Source: example/lib/main.dart:92-93

### Interruption is a manual control, not speech

- Claim: Interruption is a user action that invalidates the current generation and flushes platform playback where supported. It is not triggered by the user speaking over a reply. The word "where supported" means flushing is not guaranteed on every platform.
- Evidence: "Manual interruption | Generation invalidation plus platform playback flushing where supported". The public API lists `create`, `start`, `interrupt`, `stop`, `dispose`, and the README says "At a user interruption: await agent.interrupt()". The example exposes it as a button labelled Interrupt.
- Source: doc/capabilities.md:22, README.md:37, README.md:87-88, example/lib/main.dart:251-256

### Background, wake word, focus loss, route change and thermal pressure suspend the session

- Claim: Background operation and wake word are unsupported. The session stops or suspends in background, on OS focus loss, on route removal and on severe thermal pressure, and resuming requires an explicit Start.
- Evidence: Capabilities lists "Background / wake word | Unsupported; session suspends in background", "Route change | Suspend", and "Thermal | Severe/serious system signal suspends". README says "Stop on backgrounding. OS focus loss, interruption, route removal, or severe thermal pressure suspends operation; resuming requires an explicit Start." The example calls `onBackground()` for paused, hidden and detached states and deliberately ignores `inactive` so permission prompts do not invalidate Start. The wiki says backgrounding cancels preparation and stops listening.
- Source: doc/capabilities.md:24-26, README.md:60, README.md:118-121, example/lib/main.dart:54-64, wiki/product/example-model-catalog.md:15

### Replies are fixed local demo rules, not a chat model

- Claim: The example must keep saying replies are deterministic demo rules. No general LLM is advertised, and the optional local LLM is a separate path.
- Evidence: The conversation section says "Replies are fixed demo rules, not an LLM. Try “hello”, “what is your name?”, or “thank you”." The reply card placeholder says "The fixed local demo reply appears here." README says these are "fixed local demo replies, not a general-purpose LLM conversation." The consumer guide says the replies demonstrate recognition and synthesis and "It is not a general-purpose chat model." The wiki says "no general LLM model is advertised". Capabilities says the default logic is a host-supplied deterministic Dart function.
- Source: example/lib/main.dart:236-238, example/lib/main.dart:277, README.md:180-181, doc/model-catalog.md:14-15, wiki/product/example-model-catalog.md:15, doc/capabilities.md:17

### Transcript and reply wording must respect what is recognised and synthesised

- Claim: Native recognition produces revisable partials, so partial text is provisional. Reply text is a complete reply, with no sub-sentence streaming claim. Reply input has length limits and an invalid reply interrupts the turn.
- Evidence: Capabilities: "streaming transducer with revisable partials"; "complete reply input"; "Sentence callback feeds bounded playback; no sub-sentence streaming claim". README: invalid replies emit a typed fault and interrupt the turn before native synthesis, and the next turn can proceed. The example transcript placeholder already reads "Your partial and final transcript appears here."
- Source: doc/capabilities.md:16-19, README.md:107-109, example/lib/main.dart:271

### Start gating and failure semantics

- Claim: Start requires a verified, created engine and microphone permission. A failed setup cannot enable Start. Controls are disabled while an operation is busy. Interrupt and Stop are enabled only when a session exists.
- Evidence: The consumer guide says Start comes only after model verification and native engine creation succeed, then microphone permission is granted. The wiki says "Failed setup cannot enable Start." The README says a missing or corrupt asset, or a refused permission, is an explicit `AgentFailure` with no cloud fallback. In the example, Start uses `canStart && !operationBusy`, and Interrupt and Stop use `hasSession && !operationBusy`.
- Source: doc/model-catalog.md:9-10, wiki/product/example-model-catalog.md:15, README.md:101-104, example/lib/main.dart:246-263

### The existing status line is a live region and must stay one

- Claim: The example already has a single status text exposed as a semantics live region with key `status`. A new activity display lives alongside the conversation controls and must remain accessible in the same way.
- Evidence: A `Semantics(liveRegion: true)` wraps `Text(controller.status, key: const Key('status'))`. The text content comes from the controller, which was outside the read scope. Its strings are [UNVERIFIED].
- Source: example/lib/main.dart:175-178

### English-only, catalog-limited voice copy

- Claim: Three English speech packs are offered. Speaker labels are integer ids 0 through 108 (VCTK only), with no invented names, gender or accent. VCTK is a speaker choice, not a language or quality ranking. Other languages, Piper and physical-device quality are outside the catalog.
- Evidence: README says "this catalog does not invent names, gender, or accent" and "No Hebrew, other-language, physical-device performance, or voice-quality guarantee is implied." The consumer guide and wiki repeat this. The example shows the speaker control only for VCTK, and its items are the bare integer text `$id`.
- Source: README.md:139-144, doc/model-catalog.md:17-20, wiki/product/example-model-catalog.md:13, example/lib/main.dart:117-134

### No quality, performance or qualification claim is allowed

- Claim: The product has no physical-device qualification, the benchmark targets are unratified and must not be advertised as measured performance, and the VITS allocation gate is open. Evidence that exists is limited to emulator observation of listening state and offline restart.
- Evidence: Capabilities: "Device measurements | No physical Android/iPhone qualification"; "Emulator verification | Android catalog download/cancel/retry, native listening state and offline restart observed; no physical speech/audio qualification"; "The benchmark targets in the PRD remain unratified and must not be advertised as measured product performance." The 0002 gates (VITS allocation, physical mobile qualification, clean consumer-install) "remain OPEN" and "Do not advertise them as closed."
- Source: doc/capabilities.md:27-28, doc/capabilities.md:33-36, doc/capabilities.md:92-104

### Offline and internet wording must stay accurate

- Claim: Only preparation (download) needs the internet. Recognition and playback run offline after download. Later launches restore the installed pack with networking disabled, and a missing or damaged install never silently downloads.
- Evidence: The disclosure card says "Preparation needs internet; conversations do not." The intro says "Download once, then speech recognition and playback run offline." The consumer guide says startup uses a network-disabled preparation factory.
- Source: example/lib/main.dart:93, example/lib/main.dart:289-300, doc/model-catalog.md:12-13, doc/model-catalog.md:77-79

### The disclosure card carries source and license wording and is not part of activity

- Claim: `_DisclosureCard` is a collapsed `ExpansionTile` titled "Files, sources, and licenses" saying the catalog pins each source, size and checksum and that license records download with the model. It is placed between the model setup block and the Conversation heading. It is outside the scope of this work item.
- Evidence: The widget is const, placed before the `Conversation` title, and its text is as stated.
- Source: example/lib/main.dart:232-234, example/lib/main.dart:286-302

### Flutter web differs, but the example copy does not cover it

- Claim: Flutter web is a separate WASM profile with a non-streaming offline recognizer, and its microphone session is [UNVERIFIED]. Native partial-transcript wording must not be extended to a web claim.
- Evidence: Capabilities states the web recognizer is VAD plus one non-streaming offline recognizer, and "Browser microphone-to-speaker and compact-catalog WASM load remain [UNVERIFIED]". README's platform table says the same.
- Source: doc/capabilities.md:6, doc/capabilities.md:16, README.md:57

## Constraints discovered

1. Keep the half-duplex statement. Do not write activity text that suggests the app listens while a reply plays, or that the user can talk over a reply. Keep "Listening pauses while a reply plays." (example/lib/main.dart:93; doc/capabilities.md:20-21)
2. Do not use the terms barge-in, full duplex, hands-free, always listening, or wake word, except to deny them. (doc/capabilities.md:21,24)
3. Interrupt must stay an explicit user control with manual semantics. Do not describe it as speech-triggered, and do not promise that audio stops instantly on all platforms ("where supported"). (doc/capabilities.md:22)
4. Stop remains an explicit control. Backgrounding stops listening and resuming requires an explicit Start. Activity copy must not claim background listening or auto-resume. (README.md:118-121; wiki/product/example-model-catalog.md:15)
5. Keep the `inactive` lifecycle state as a no-op so permission prompts do not invalidate Start. (example/lib/main.dart:62-64)
6. Keep Start, Interrupt and Stop enablement rules unchanged: Start needs `canStart` and no busy operation, Interrupt and Stop need an existing session and no busy operation, and failed setup never enables Start. (example/lib/main.dart:246-263; wiki/product/example-model-catalog.md:15)
7. Keep the statement that replies are fixed demo rules, not an LLM, and keep the example phrases. Do not call the reply "an answer from an assistant" or similar. (example/lib/main.dart:236-238; README.md:180-181)
8. Describe transcript text as provisional while it is partial. Do not claim accuracy. Do not claim sub-sentence streamed speech. (doc/capabilities.md:16,19)
9. Keep all UI copy in English. No Hebrew, no other language, no speaker names, gender or accent. Speaker labels stay as integer ids. (README.md:139-144; doc/model-catalog.md:17-20)
10. Do not claim measured latency, speed, voice quality, recognition accuracy, physical-device behavior or production qualification. The only recorded evidence is emulator observation and macOS compile evidence. (doc/capabilities.md:27-28,33-36)
11. Do not claim the 0002 gates are closed (VITS allocation, physical mobile qualification, clean consumer-install). (doc/capabilities.md:92-104)
12. Keep "preparation needs internet; conversations do not" accurate. Do not suggest network use during a conversation or cloud fallback. (example/lib/main.dart:289-300; README.md:101-104)
13. Keep the live-region semantics on the status text. A new activity display should not be silent to assistive technology. (example/lib/main.dart:175-178)
14. Do not edit the README, doc/capabilities.md, doc/model-catalog.md or wiki/product/example-model-catalog.md as part of copy-only work unless a later phase finds a documented statement that becomes false. None of them currently describes an activity display. [UNVERIFIED beyond the sections read]
15. The README says the example's phrase is “what is your name”, while the example shows “what is your name?”. This difference is cosmetic and not a constraint. (README.md:180; example/lib/main.dart:238)

## Unresolved

- Which activity states the controller and the public typed events actually expose (README mentions "lifecycle, activity, transcript, reply, and failure" events) was not read. Which states can honestly be shown is [UNVERIFIED]. (README.md:44)
- What strings `controller.status` currently produces, and whether they already mention listening, speaking or hearing, is [UNVERIFIED]. The controller was outside the read scope. (example/lib/main.dart:178)
- Whether a distinct "hearing speech" state can be shown from VAD, as opposed to a transcript arriving, is [UNVERIFIED]. No source read claims a user-visible VAD signal.
- Whether the Interrupt button has any effect when nothing is playing is [UNVERIFIED]. The example enables it whenever a session exists. (example/lib/main.dart:253)
- Whether existing example tests assert the exact current copy (for example the literal conversation sentence) was not read and is [UNVERIFIED].
- Whether the wiki lint requires a product note update when example copy changes was not checked. [UNVERIFIED]
