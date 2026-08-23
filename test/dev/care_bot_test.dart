import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/dev/care_bot.dart';
import 'package:sooey/game/screens/crest_screen.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/feed_menu.dart';
import 'package:sooey/game/screens/home_screen.dart';
import 'package:sooey/game/screens/stats_screen.dart';
import 'package:sooey/game/screens/truffle_hunt.dart';

void main() {
  group('pressToward', () {
    test('cycles the home cursor until the icon it wants is lit', () {
      final home = HomeScreen();
      expect(home.selected, isNull, reason: 'a new home screen is parked');
      expect(pressToward(BotGoal.slop, home), Button.a);

      home.selected = DeviceIcon.wallow;
      expect(pressToward(BotGoal.slop, home), Button.a);

      home.selected = DeviceIcon.feed;
      expect(pressToward(BotGoal.slop, home), Button.b);
    });

    test('treats and slop share the feed icon but not the caret', () {
      final menu = FeedMenu();
      expect(menu.treat, isFalse, reason: 'the menu opens on slop');
      expect(pressToward(BotGoal.slop, menu), Button.b);
      expect(pressToward(BotGoal.treat, menu), Button.a);

      menu.treat = true;
      expect(pressToward(BotGoal.treat, menu), Button.b);
    });

    test('guesses in the hunt, and waits out the reveal', () {
      final hunt = TruffleHunt();
      expect(hunt.revealing, isFalse);
      expect(pressToward(BotGoal.play, hunt), Button.a);

      hunt.pigWentLeft = true; // what a guess leaves behind
      expect(hunt.revealing, isTrue);
      expect(pressToward(BotGoal.play, hunt), isNull);
    });

    test('takes any crest rather than shopping for one', () {
      expect(pressToward(BotGoal.slop, CrestScreen()), Button.b);
    });

    test('never presses on the death screen', () {
      // B there is Restart, which would erase the life just watched.
      for (final goal in BotGoal.values) {
        expect(pressToward(goal, DeathScreen()), isNull);
      }
    });

    test('backs out of a screen it did not ask for', () {
      expect(pressToward(BotGoal.slop, StatsScreen()), Button.c);
    });
  });
}
