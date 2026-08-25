import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/feed_menu.dart';

import 'screen_test_support.dart';

void main() {
  test('opens on slop, the ordinary meal', () {
    expect(FeedMenu().treat, isFalse);
  });

  test('keeps the feed icon lit while it is open', () {
    // The strip is how the player knows where they are. Losing the highlight
    // on the way into a submenu would read as having left the menu.
    expect(FeedMenu().litIcon, DeviceIcon.feed);
  });

  test('A toggles between the two', () {
    final s = FeedMenu();
    drive(s, 'A', testContext());
    expect(s.treat, isTrue);
    drive(s, 'A', testContext());
    expect(s.treat, isFalse);
  });

  test('B feeds whichever is showing', () {
    final slop = drive(FeedMenu(), 'B', testContext()).single;
    expect((slop as Act).action, PetAction.slop);

    final treat = drive(FeedMenu(), 'AB', testContext()).last;
    expect((treat as Act).action, PetAction.treat);
  });

  test('C backs out without feeding anything', () {
    expect(drive(FeedMenu(), 'C', testContext()).single, isA<Pop>());
  });

  group('the frame', () {
    test('draws both choices, so the alternative is visible', () {
      // Check each icon inside its own rows AND its own columns. Scanning every
      // row is not enough: the caret sits at columns 10-12 on rows 12-13, inside
      // the slop icon's column range and always drawn, so a whole-frame scan
      // would let the caret stand in for the icon it is supposed to be marking.
      final rows = FeedMenu().compose(testContext(), 0).toAscii().split('\n');
      bool litInIconRows(int from, int to) =>
          rows.sublist(3, 10).any((r) => r.substring(from, to).contains('#'));

      expect(litInIconRows(8, 15), isTrue, reason: 'slop icon missing');
      expect(litInIconRows(17, 24), isTrue, reason: 'treat icon missing');
    });

    test('marks the two choices differently', () {
      // The caret is the only thing that says which one B will pick.
      final slop = FeedMenu().compose(testContext(), 0).toAscii();
      final treat = (FeedMenu()..treat = true)
          .compose(testContext(), 0)
          .toAscii();
      expect(slop, isNot(treat));
    });
  });
}
