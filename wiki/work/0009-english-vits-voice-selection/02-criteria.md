# Acceptance criteria: English VITS lexicon voice selection

## Frozen

- Frozen at: 2026-09-21
- Frozen by: root after plan-review-02 PASS and user authorization to implement all open plans

## Criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-001 | When the catalog is read, it shall expose exactly three English options: the existing LJS compact pack, the existing LJS standard pack, and one compact VCTK pack whose speaker count is 109. | Catalog unit tests read titles, ids, languages and speaker counts. | A fourth language or a Piper entry appears, or VCTK reports speaker count 1. |
| AC-002 | When the VCTK catalog files are inventoried, every synthesis file and notice shall have a frozen source revision, exact byte length, SHA-256 digest and installed license path, and those values shall match a fresh download. | Catalog inventory file plus the catalog verifier after a real download. | A URL without a digest is accepted, or a downloaded file with a different digest is activated. |
| AC-003 | When a host creates a session with no speaker id, the native generate path shall use speaker id 0. | Dart create test and native smoke using LJS assets. | Create without an id synthesizes with a non-zero speaker or fails. |
| AC-004 | When a host creates a session with a speaker id below 0, or with an id greater than or equal to the sherpa-reported speaker count, creation shall fail with unsupported-profile and shall not open the microphone. | Dart validation test and native create failure test. | A negative or too-large id is stored and later used in generate. |
| AC-005 | When a ready VCTK session receives a speaker id in range 0 through 108 inclusive, the next synthesized reply shall use that id and no catalog download shall start. | Controller test plus native setter success when VCTK assets exist. | Speaker change re-enters preparation, or generate keeps the previous id after a successful set. |
| AC-006 | When a ready session receives a speaker id outside the sherpa-reported range, the setter shall fail with unsupported-profile and the previous id shall remain in use. | Dart and native setter tests. | A failed set replaces the stored id or destroys the session. |
| AC-007 | When the example selects an LJS option, it shall hide the speaker control, persist catalog id, treat a missing speaker field as 0, and keep Start gated on verified LJS preparation as today. | Example storage and controller tests. | LJS shows 109 speakers, or a missing speaker field blocks Start. |
| AC-008 | When the example selects VCTK, it shall show integer speaker labels 0 through 108, persist catalog id and speaker id, restore both offline without creating a network client, and refuse Start while the saved speaker id is out of range. | Example storage and controller tests with a network-disabled factory. | Restore downloads VCTK again, or Start succeeds with speaker id 109. |
| AC-009 | When the user changes catalog pack, the example shall dispose the previous session before preparing the next pack. | Existing controller switch test updated for three options. | Two native sessions remain live after a pack change. |
| AC-010 | When library consumer docs and the README are read after this change, they shall state three English catalog options, describe VCTK as a speaker choice, state that speaker labels are integer ids, and state that Piper, other languages and physical-device quality remain outside this catalog. | Review README, catalog, models, capabilities, preparation and testing guides. | A shipped library guide still says the catalog is only two LJS packs or claims a quality ranking. |
| AC-011 | When the wiki index and product records are updated, the example catalog product document shall describe the VCTK speaker control, a new architecture decision shall record the VCTK-plus-speaker-id choice, and the earlier catalog decision shall remain reachable. | Wiki lint and index reachability. | The new decision is missing, or the earlier catalog decision is deleted. |

## Non-functional criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-012 | When format, analyzer and wiki lint run on the changed Dart and wiki tree, they shall pass with the repository's fatal-info analyzer settings. | Run the documented format, analyze and lint commands and paste output. | Analyzer info, wiki fence-in-plan or missing index link remains. |

## Explicitly not required

Hebrew or other non-English packs.

Piper, eSpeak data directories, Kokoro, Kitten, Matcha or system TTS.

A VCTK full-precision pack.

Named speakers, gender or accent metadata.

Physical-device audio, memory or thermal qualification.

Closing the existing VITS allocation gate.

LLM behavior changes.

Desktop bridges from work item 0008.

## Verdict log

| Round | Date | Verdict | Report |
|---|---|---|---|
