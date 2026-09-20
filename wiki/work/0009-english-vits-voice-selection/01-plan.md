# Plan: English VITS lexicon voice selection

## Goal

A user of the example can keep the existing English LJS precision packs or download one additional compact English VCTK pack and choose a speaker by integer id. Hosts using the library catalog see the same three English options, can pass a speaker id into session creation, and can change that id on a live session without another download. Library and example documentation describe the new voice choice, its limits, and the files a consumer must read.

## Approach

Keep the current complete-bundle catalog, preparation service, offline restore path and VITS lexicon native loader. Do not introduce Piper, eSpeak data directories, Kokoro, Kitten, Matcha, new recognizers or new languages.

Add a third catalog entry that reuses the already pinned compact Zipformer and Silero files and substitutes VCTK INT8 synthesis files. The entry advertises English, a speaker count of 109, and honest size or purpose text without quality rankings. Implementation first records a machine-readable inventory with exact lengths, SHA-256 digests, frozen source revisions and license notices, then copies those values into the catalog and the existing inventory file.

Extend the public catalog option with a speaker count. Extend agent creation and the native session with a speaker id that defaults to zero. After the synthesizer exists, the native layer asks sherpa for the speaker count and rejects an out-of-range id. Add a native setter so the example can change speaker on a ready VCTK session without disposing the recognizer. A change applies to the next synthesized reply; an utterance already being generated keeps its original id. A rejected setter leaves the previously accepted id in place and leaves the session alive.

The example adds a speaker control that appears only when the selected option has more than one speaker. Selection persistence stores both catalog id and speaker id. A missing or out-of-range saved speaker id falls back to zero for a single-speaker pack and fails closed for a multi-speaker pack until the user picks a valid id. Changing catalog packs still disposes the previous session. Changing only the speaker does not re-download.

Documentation is part of delivery, not a follow-up. Update the library README, every consumer guide that currently says the catalog is two LJS packs, the testing note for catalog verification, the example catalog product record, and the wiki index. Write a new architecture decision for speaker-id selection instead of silently rewriting the earlier catalog decision. That earlier decision stays and records that it described precision packs, not speakers.

## Why this approach

Research shows only two official English VITS lexicon voices: LJS, already shipped, and VCTK. Lessac and the rest of the English sherpa list are Piper data-directory models. Replacing LJS would discard the verified fixture. Adding both VCTK precisions would duplicate the large recognizer download again. Sharing one recognizer across voices would break the complete-bundle catalog contract from work item 0006. Recreating the whole session on every speaker change would reload Zipformer just to change an integer. The chosen shape keeps the catalog honest, adds one compact multi-speaker pack, and changes speaker through the generate id that sherpa already accepts.

## Steps

1. Record the VCTK inventory. Download the INT8 model, tokens, lexicon and license notices from a frozen Hugging Face revision, measure bytes and SHA-256, and write them into the catalog inventory file using the same roles as LJS. Stop if a file cannot be pinned or its card does not supply a notice that can be installed beside the weights.

2. Publish the third catalog option. Add speaker count to the catalog option type. Keep the two LJS entries at speaker count one. Add the compact VCTK entry at speaker count 109. Keep profile, runtime and input rate unchanged. Update catalog tests so they assert three English options, distinct ids, LJS speaker count one, VCTK speaker count 109, and unchanged redirect origins.

3. Thread speaker id through the Dart facade. Session creation accepts an optional speaker id defaulting to zero. A live setter updates the native id. Values below zero are rejected before the native call. Catalog speaker count is used by hosts for display; native speaker count remains the generate-time check.

4. Extend the native session and both existing mobile bridges. Add speaker id to the create configuration. After successful synthesizer creation, query sherpa speaker count and reject an id outside zero inclusive through count minus one. Store the accepted id and use it in generate. Add a setter that repeats the same range check. If the setter rejects the id, it must not write the new value and must not destroy or recreate the session. Keep generate cancellation and ownership unchanged.

5. Teach native tests the new id. Existing smoke and failure tests keep speaker zero. Add a failure case for an out-of-range id at create, a failure case for an out-of-range setter, and a success case that sets a non-zero VCTK id when those assets are present in a host inventory. If only LJS assets are on the machine, the multi-speaker success case stays skipped and is recorded as a catalog-asset gate, not a silent pass.

6. Update example storage and the screen controller. Persist catalog id and speaker id together. Restore a known catalog id offline as today. Hide the speaker control for LJS. Show integer speaker labels zero through 108 for VCTK without invented gender or accent names. Changing speaker on a ready session calls the live setter and saves the id. Changing packs disposes the old session first.

7. Update example UI copy and widget tests. The model picker remains the speech configuration. Helper text must stop saying every choice is the same LJS voice. Add controller and storage tests for persist, restore, single-speaker fallback to zero, damaged speaker field, and refusal to start VCTK with an out-of-range id.

8. Update library documentation in the same change. Rewrite the catalog counts and voice wording in the README, the catalog guide, the local pack guide, the capabilities table, the preparation guide and the testing guide. State that VCTK is an English speaker choice, not a language or quality ranking, and that Piper remains deferred.

9. Update wiki product records. Refresh the example catalog product document and the index. Add an architecture decision that records VCTK plus speaker id as the English lexicon voice choice. Leave the earlier catalog decision in place and point it at the new decision for speaker selection.

10. Run format, analyzer, Dart tests, wiki lint and the catalog verifier after the new inventory exists. Paste command output in verification. Do not claim physical-device quality.

## Interfaces and shared decisions

Catalog options remain complete English speech bundles. The new id is a compact VCTK bundle, not a TTS-only overlay.

Speaker count is a required catalog field. LJS is one. VCTK is 109. The example labels speakers as integer ids unless a later inventory finds a verified name table in the selected archive.

Speaker id is an integer greater than or equal to zero. Creation default is zero. The native layer rejects any id outside the sherpa-reported range after the synthesizer is created. A failed setter keeps the last accepted id and does not dispose the session.

Changing speaker does not download and does not dispose the session. It does not interrupt an in-flight utterance. The next reply uses the new id.

Changing catalog pack still disposes the previous session, prepares the new bundle, and resets speaker id to the saved id for that pack or to zero.

Profile, runtime and required roles stay as they are. No new role is added. No Piper data directory is accepted.

Public errors for a bad speaker id use the existing unsupported-profile failure. Do not add a new error code in this item.

Documentation names the three catalog options, the speaker control, the integer-id limit, the unchanged offline contract, and the still-open VITS allocation and physical-device gates.

Work item 0008 is not edited except that this item's new native symbols must be added to the Android and iOS bridges that already exist. Desktop bridges from 0008 remain that item's work.

## Risks

| Risk | Likelihood | Impact | Mitigation | Trigger that means it happened |
|---|---|---|---|---|
| VCTK files on main have moved or changed | Medium | Inventory cannot be pinned | Freeze a revision and fail integrity on mismatch | Hash or size differs from the recorded inventory |
| VCTK INT8 cannot synthesize the demo replies | Medium | Example sounds broken or silent | Keep LJS as the first catalog option; test demo phrases against VCTK before advertising the pack | Native generate fails or omits demo vocabulary |
| Live speaker setter races with generate | Medium | Reply uses the wrong speaker or crashes | Store the id atomically and read it once per generate; do not rebuild the synthesizer | A reply starts while the setter runs and the session faults |
| 109 speakers overwhelm the example picker | Medium | Users cannot find a useful voice | Use a searchable or scrollable integer list; do not invent a shortlist of best voices | Review or usability feedback says the control is unusable |
| JNI or iOS create path forgets the new field | Medium | Mobile builds keep speaker zero | Add the field to both existing bridges and a Dart test that the create payload includes it | A mobile create still sends only paths |
| Documentation still says two LJS packs | High if omitted | Consumers ship the old story | Treat doc files as owned tasks and lint the index | A shipped guide still denies voice choice |

## Rollback

Remove the VCTK catalog entry and speaker fields, restore speaker id zero in native generate, restore selection JSON to catalog id only, and restore the documentation wording that the catalog is two LJS precision packs. Existing LJS installations remain valid. A saved selection that includes a speaker id must still be readable as catalog id only after rollback, so restoration cannot require the extra field. Do not delete wiki artifacts; supersede the new architecture decision if the choice is reversed.

## Out of scope

Hebrew or any non-English pack.

Piper, eSpeak data directories, Kokoro, Kitten, Matcha, system TTS and voice cloning.

A VCTK full-precision pack.

Sharing one recognizer install across catalog ids.

Speaker given names, genders, accents or quality scores unless the selected archive itself contains a verified table.

LLM changes, wake word, barge-in, physical-device qualification, consumer native packaging, and the open VITS allocation gate.

Editing work item 0008 plans or implementing desktop bridges here.

## Verification approach

Unit tests cover catalog count, speaker counts, rejected negative ids, rejected out-of-range ids, a failed setter that leaves the previous id and the session, selection persist and restore, and single-speaker packs ignoring a missing speaker field.

Native tests keep the LJS speaker-zero smoke path. They add create and setter rejection for an illegal id. Multi-speaker generate is run only when the VCTK INT8 files from the new inventory are present.

After inventory exists, the catalog verifier downloads all three packs, checks hashes and records role paths. Wiki lint must pass. Format and analyzer must pass. Verification pastes those command outputs and does not treat emulator absence as a documentation pass.
