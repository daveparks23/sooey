# M4 — decisions taken without asking

Every ruling made on your behalf while executing `m4-local-loop-plan.md`,
in the order they were made. You can undo any of them; this exists so none
of them is a decision made in secret.

The short version: four changed behaviour or history, eleven were defects
in the plan's own test code, and the rest were bookkeeping. Full text below.

## R1

accept the import cycle `sprite_registry -> icon_sprites/crest_sprites -> device_screen -> sprite_registry`. Dart permits cyclic imports, and there is no const-initialization cycle because `device_screen.dart` references nothing from the sprite files. Keeping `kDeviceIcons`/`kCrests` beside their art is worth it. — Cost if wrong: Task 5/6 fails to compile; fallback is to move the two maps into `lib/device/icon_strip.dart` and have the sprite tests assert individual sprites. Fallback carried in both dispatches.
## R2

Task 10's `draws the mounds over the pig, not under it` asserted on the RIGHT mound while `_AlwaysLeft` sends the pig LEFT, so the pig never overlaps it and the test passes whatever the draw order. Retargeted at the left mound (cols 2-6), which the pig does cover. — Cost if wrong: the ordering bug the test exists to catch ships unnoticed.
## R3

Task 11's `keeps a twenty-day life inside the gutter` asserted the buffer is 16x32, which `LcdBuffer` guarantees unconditionally. Replaced with a count of lit dots in the gutter columns. — Cost if wrong: pips could overflow the gutter onto the stone with nothing failing.
## R4

Task 12's `cleaning clears the pen` never fed the pig, and only slop schedules a poop, so `poops` was empty before and after and the test could not fail. Amended to feed first and assert the pen is dirty before cleaning it. — Cost if wrong: cleaning could stop working silently.
## R5

Task 12's two blink tests pressed A again after feeding, moving the cursor from feed to wallow, so the second action was an accepted wallow rather than a refused slop and both tests would fail. Amended the press sequences to reopen the feed menu on the still-selected feed icon. — Cost if wrong: two failing tests in the fix loop.
## R6

Task 15's acceptance test used five presses of A to reach clean; from feed that lands on stats. Replaced with the `while (c.litIcon != ...)` form the same test already uses for play. — Cost if wrong: a failing acceptance test.
## R7

Task 13's `IconStrip` computed `lit` as `i == selected`, so an icon that is both selected and blinking stayed lit and the refusal blink was invisible in exactly the case it matters (you refuse the action on the icon you have selected). Amended to `i == selected && i != hidden`. — Cost if wrong: refusals give no feedback at all, which is the one thing the blink exists for.
## R8

Task 1 Step 6 listed both `lcd_bars.dart` and `lcd_matrix.dart` exports and then said to add only the latter. Settled: Task 1 adds `lcd_matrix.dart`, Task 2 Step 4 adds `lcd_bars.dart`. — Cost if wrong: a broken build for one step.
## R9

`test/widget_test.dart` asserts "the app boots to the dev menu", which Task 15 falsifies by moving the dev menu to /dev. The plan never updated it, so Task 15 would have finished on a red suite while claiming green. Amended Task 15 to rewrite that test (boots to DeviceShell, dev-menu text absent, widget unmounted so DevicePage's animation timer is not left pending). Task 15 brief regenerated. — Cost if wrong: a failing widget test at the last task, plus a pending-timer error if the unmount is unnecessary.
## R10

the brief's predicted "11 tests" was a controller arithmetic error; the brief's own code block defines 9, and the 99->108 suite delta corroborates 9. Plan text corrected to stop quoting a count for a directory that already held other test files. Implementation was never wrong. — Cost if wrong: none; documentation only.
## R11

amend commit 6a1863c to exclude the kGrave hunk and restore that edit to the working tree uncommitted, rather than leaving it committed under an unrelated message. Judged reversible and routine: unpushed local feature branch, content backed up twice, old commit still in the reflog. Leaving it is worse — it buries someone else's in-progress work in a commit that does not mention it. — Cost if wrong: Dave's grave edit has to be restored from the backup file or the reflog.
## R12

beyond the reviewer's minimal fix (add a kMound.validate call), also change the cast-wide sweep to accumulate every failure instead of throwing at the first. The reviewer confirmed the sweep aborts at prop.grave and never reaches the ten sprites after it; Task 6 adds eleven more in the same position, so without this the project's main sprite guard stays off for the rest of the plan. Also makes the grave report all its problems rather than only the row count. — Cost if wrong: a slightly more complex test; the guarantee it restores is the whole point of the sweep.
## R14

swept the plan for the defect that caused R11. Tasks 6, 10, 11 and 13 all still had directory-scoped `git add`, and Task 6's was `git add lib/sprites`, i.e. the identical trap with prop_sprites.dart dirty again. All four rewritten to explicit paths, briefs regenerated, and two new Global Constraints added: never `git add` a directory, and prove a file untouched with `git diff <base>..HEAD -- <path>` rather than `git status`. — Cost if wrong: none; strictly narrows what gets staged.
## R15

the reviewer is right and the plan is wrong. `test('draws both choices...')` asserts only `ascii.contains('#')`, which cannot fail: compose() unconditionally blits two opaque 7x7 icons, so it would pass with one icon, no icons, or both stacked. The test's name claims something it does not check. Routed to a fix round with a replacement that asserts each icon is lit within its own column range. — Cost if wrong: a slightly longer test that pins the layout; if the layout constants later move deliberately, this test moves with them.
## R16

swept the plan for the same pattern. Of eleven `contains('#')` sites, most are real (absence assertions, column-targeted checks, lit-vs-dim strip buffers). One more was the identical tautology: Task 11's `draws the stone`, which would pass on the crest or pips alone. Strengthened in the plan before Task 11 is built, to require the stone fill most of the middle sixteen columns. Task 7's egg assertion is weak but can genuinely fail (a blank frame) and is already committed — left alone. — Cost if wrong: Task 11's test now encodes the grave's centred position, so a regrave that changes its width needs the threshold revisited.
## R17

my R15 replacement was itself flawed and needs a second correction: constrain the scan to the icons' own rows (3-9) as well as their columns, so the caret cannot satisfy either assertion. Also require the deliberate-failure check to be run for BOTH icons, not one — checking a single side is what let this through. — Cost if wrong: the test now pins both the icon columns and the icon rows, so a layout change needs both updated.
## R19

my R2 fix to the mound test was ALSO insufficient, and for a subtler reason than the first time. The reviewer simulated blit against the real sprite bytes: at dx=-9 the pig's own artwork puts dots at columns 2-6 of row 14, the same columns as the mound's bottom row, so `contains('#')` yields `#####` correct vs `..###` reversed — both pass. Row 13 would have discriminated (`.###.` vs nothing). Production code was always correct; only the regression test was blind. Replaced with exact-string assertions on rows 13 and 14. — Cost if wrong: the test now pins the mound's exact art, so a mound redraw needs it updated. That is the right trade for a test whose entire purpose is catching one specific reversal.
## R20

folding the Minor redundant-import fix into the same round rather than deferring it. `flutter analyze` currently reports one info-level `unnecessary_import` in the very file being fixed; deferring it means carrying a dirty analyzer through five more tasks, where it becomes noise that hides real findings at the final review. One line, same file, same round. — Cost if wrong: negligible.
## R21

sixth plan defect, and this one would not even compile: I wrote `expect(c.context.transientPose, isNot(PetPose.sad))`, but PetPose is {idle, eating, sleeping, wallowing}; `sad` belongs to PetMood, which is a separate axis and outside the controller's scope entirely. The implementer deleted the line, which was right. But that line was the only thing in the controller's tests encoding "a refusal must not change how the pig looks", so its removal leaves a real gap — and a naive `isNull` replacement would be wrong, because the pet still carries an `eating` pose from the accepted feed earlier in the same sequence. Asked the reviewer to recommend a falsifiable replacement rather than deciding it myself. — Cost if wrong: the premise rule keeps its structural guarantee (the controller has no code path from a refusal to mood) but loses its regression test here; moodFor's own test elsewhere still covers the rule directly.
## R22

accepted the `prefer_initializing_formals` deviation. It clears an analyzer info without changing the public API, since Dart exposes the parameter as `clock:` at call sites regardless. Reviewer asked to confirm the default-parameter behaviour is unchanged. — Cost if wrong: caught by the reviewer's check.
## R25

ninth plan defect, found by controller pre-flight rather than by a subagent. Task 14's widget test used `findsNExactly(3)`, which does not exist in flutter_test at any version; the real matchers are `findsNWidgets(n)` and `findsExactly(n)` (verified directly in this checkout's matchers.dart:131,147). Would have been a compile error. Corrected to `findsExactly(3)` and brief 14 regenerated. — Cost if wrong: none; verified against the SDK source on this machine.
## R26

tenth plan defect, and this one I inherited rather than invented: `expect(d, d.toInt())` on an int is `expect(d, d)`. The same idiom sits in the pre-existing test/lcd/lcd_painter_test.dart, which is where I copied it from, so it predates the milestone. Replaced with a sweep asserting the glass fits its box and leaves no whole dot unused — the shape lcd_painter_test.dart's own `takes whichever constraint binds first` already uses, so this brings glassDotSize up to the standard the codebase had already set elsewhere. The pre-existing instance is out of this milestone's diff; flagged for the final review rather than fixed here. — Cost if wrong: none; the replacement was validated by the reviewer against three bug classes and by a deliberate-failure run.
## R27

the doc comment on _buttonFor says "arrow keys and enter" while the code also binds space and keyA/keyB/keyC. The bindings are deliberate and stay (a three-button device should not make you hunt for arrow keys in a browser, and a key is a physical button by another name either way, so §6 holds). The defect is the comment under-describing the code — which is how someone later deletes a binding they think is stray. Comment corrected in the plan and routed to a fix round. — Cost if wrong: none; behaviour unchanged.
## R28

`hide Form` in device_shell.dart is not load-bearing. The reviewer traced every reachable import and found hog_sim's Form never enters this file's namespace, because Dart imports are not transitive without an explicit export. Keeping it: harmless, defensive against a future direct hog_sim import, and consistent with pet_preview_page.dart where it IS needed. NOTE the over-statement was in my dispatch prompt only — the plan's and design doc's Global Constraints both state it correctly and conditionally ("any file importing both"), so no document needs correcting. — Cost if wrong: a no-op hide clause.
## R29

eleventh plan defect, and my dispatch actively doubled down on it: I told the implementer `hide Form` was "genuinely" needed in device_dev_page.dart "unlike the shell". Wrong. The hog_sim import was entirely unused — Dart does not require importing a type to call members on a value returned by an already-imported API, so `pet.stage.name` and friends resolve without it. `flutter analyze` flagged unused_import. The implementer removed the import, kept the harmless `hide Form` for consistency, and flagged it rather than implementing my instruction verbatim. Accepted. — Cost if wrong: none; the analyzer is the arbiter here and it is clean.
## R23

seventh plan defect. Deleting the uncompilable PetPose.sad line was right, but it left "a refusal must never put an expression on the pig" with zero executable coverage, and that is one of the two rules the game's design rests on. Replaced with `expect(c.context.transientPose, PetPose.eating)` — eating, not null, because the accepted feed two presses earlier is still running; that is precisely what makes it falsifiable in both directions. — Cost if wrong: the assertion pins a 3s window, so changing kTransientPoseMillis below the test's press sequence would break it.
## R24

eighth plan defect. `test('an egg refuses everything but the light')` never presses the light, so it would pass even if the light were refused too — and the light being allowed pre-hatch is the whole point of the exception. Extended to press the light and assert it toggles with no blink. The clock.advance before that half is load-bearing: an accepted action does not clear a prior refusal's blink, so without it the final assertion fails for the wrong reason. — Cost if wrong: if the controller does clear blinks somewhere I have not accounted for, the advance is harmless anyway.
## R18

the implementer found a genuine contradiction in my plan and resolved it correctly. `test('A guesses left and C guesses right')` and `test('is best of five and reports the wins')` both need C to record a guess; `test('C abandons the match')` needs the identical press to return Pop. No implementation satisfies both. Spec §7.4 is the binding authority and spends A and C on the two guesses, and the approved design says "B is idle during a round" — so C is a guess and there is no abandon button. Kept C-as-guess, dropped the contradicting test (10 of 11 hunt tests remain), and removed the stray `if (b == Button.c) return const Pop();` from the plan's implementation snippet, which was the other half of the same mistake. Corrected the plan and the design doc, which now states explicitly that a match cannot be abandoned and why. — Cost if wrong: the hunt is the one screen where C does not mean cancel; if that proves annoying in play, the fix is to give B the exit, since B is otherwise idle. Nothing can get stuck either way — five presses ends the match.
## R13

commit the stray `dart format` changes to test/game/screens/screen_test_support.dart and test/lcd/lcd_bars_test.dart in the same fix. They were left uncommitted by Task 5's directory-scoped `git add` and are exactly the sort of floating change that caused the kGrave accident. This also closes the Task 4 formatter Minor. — Cost if wrong: a formatting-only hunk in the fix commit.
## R30

the acceptance test's "played with" clause proves the hunt's integration flow (5 rounds genuinely drive through update(), Played fires exactly once on the 5th, applyMinigame accepts it) but NOT that win-detection is correct, because applyMinigame pays out for any score including zero. Not a defect and not fixed: truffle_hunt_test.dart already verifies scoring exactly with a seeded pig (asserts 3 wins on alternating guesses, 5 on all-left), and the acceptance test structurally cannot seed it — HomeScreen constructs TruffleHunt() directly with no injection path from the controller. Adding one purely to serve a test would be worse than the division of labour we have. — Cost if wrong: a scoring regression would be caught by the unit test, not the acceptance test.
## R31

/dev/device pins utcOffsetMinutes: 0 while / uses the device's real local offset. Plan-mandated. Accepted as-is: a dev harness benefits from determinism, its own local-time readout is self-consistent, and the divergence only affects the simulated sleep window — which is moot at 60x and above, where wall-clock correspondence has no meaning anyway. — Cost if wrong: the pig's sleep window in the harness will not line up with Dave's real clock.
