/// Noon UTC, 12 August 2025 — the instant every full-life run starts from,
/// on `/dev/life` and in the headless tests alike.
///
/// The bot's sleep/light policy keys off the pig's local hour, and the
/// sloppy preset's 35/60 rescue hysteresis is phase-sensitive to it: which
/// adult a run produces can depend on what time of day the run started. A
/// phase sweep found a multi-hour window where sloppy care mostly lands a
/// farm hog instead of a runt (see "The start phase matters for sloppy care" in
/// `life-cycle-harness-design.md`), so the page pins its clock here instead
/// of seeding from `DateTime.now()` — one fixed, tested instant rather than
/// whatever the wall clock reads when a viewer presses Start.
const int kRefNoon = 1755000000000;
