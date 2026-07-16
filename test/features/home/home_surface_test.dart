import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/home/domain/entities/home_surface.dart';

void main() {
  group('HomeSurface parsing', () {
    test('local defaults match current UX flags', () {
      final surface = HomeSurface.localDefaults();
      expect(surface.schemaVersion, kHomeSurfaceSchemaVersion);
      expect(surface.header.greeting.mode, HomeGreetingMode.staticMode);
      expect(surface.header.actions.settings.visible, isTrue);
      expect(surface.header.actions.notifications.visible, isTrue);
      expect(surface.header.actions.balanceVisibility.visible, isTrue);
      expect(surface.feed.heightToken, HomeFeedHeightToken.regular);
      expect(surface.feed.resolvedHeight, 154);
      expect(surface.layout.sectionGapBeforeFeed, 24);
    });

    test('fromJson maps header actions and feed height tokens', () {
      final surface = HomeSurface.fromJson({
        'schemaVersion': 1,
        'version': '2026-07-15T12:00:00Z',
        'ttlSeconds': 300,
        'balanceView': 'TOTAL',
        'locale': 'pt',
        'timeZone': 'America/Sao_Paulo',
        'layout': {
          'sectionGapAfterHeader': 12,
          'sectionGapAfterBalance': 10,
          'sectionGapBeforeFeed': 8,
        },
        'header': {
          'greeting': {
            'mode': 'TICKER',
            'fallback': {'template': 'TIME_OF_DAY', 'includeName': true},
            'messages': [
              {
                'id': 'm1',
                'text': 'Boa tarde, {name}',
                'durationMs': 4000,
                'priority': 10,
                'animation': 'FADE',
              },
            ],
            'rotation': {'intervalMs': 5000, 'loop': true},
          },
          'actions': {
            'balanceVisibility': {'visible': true},
            'notifications': {'visible': false},
            'settings': {'visible': false},
          },
          'spacing': {'betweenActions': 10, 'afterGreeting': 16},
        },
        'feed': {
          'heightToken': 'expanded',
          'cardPadding': 20,
          'gap': 6,
          'defaultAnimation': 'FADE',
          'items': [
            {
              'id': 'edu-1',
              'kind': 'EDUCATION',
              'priority': 1,
              'title': 'Title',
              'body': 'Body',
              'tag': 'TAG',
              'media': {'type': 'ICON', 'iconKey': 'bitcoin'},
            },
          ],
        },
      });

      expect(surface.header.greeting.mode, HomeGreetingMode.ticker);
      expect(surface.header.greeting.activeMessages, hasLength(1));
      expect(
        surface.header.greeting.activeMessages.first.resolveText('Ana'),
        'Boa tarde, Ana',
      );
      expect(surface.header.actions.notifications.visible, isFalse);
      expect(surface.header.actions.settings.visible, isFalse);
      expect(surface.feed.heightToken, HomeFeedHeightToken.expanded);
      expect(surface.feed.resolvedHeight, 200);
      expect(surface.feed.items, hasLength(1));
      expect(surface.layout.sectionGapBeforeFeed, 8);
    });

    test('clamps extreme spacing values', () {
      final layout = HomeLayoutConfig.fromJson({
        'sectionGapAfterHeader': 999,
        'sectionGapBeforeFeed': -5,
      });
      expect(layout.sectionGapAfterHeader, kHomeSpacingMax);
      expect(layout.sectionGapBeforeFeed, kHomeSpacingMin);
    });
  });

  group('HomeSurface merge / events', () {
    test('applyPatch hides settings and expands feed', () {
      final base = HomeSurface.localDefaults();
      final patched = base.applyPatch({
        'header': {
          'actions': {
            'settings': {'visible': false},
          },
        },
        'feed': {
          'heightToken': 'expanded',
        },
      });

      expect(patched.header.actions.settings.visible, isFalse);
      expect(patched.header.actions.notifications.visible, isTrue);
      expect(patched.feed.heightToken, HomeFeedHeightToken.expanded);
    });

    test('HOME_UI_GREETING enqueues ticker message', () {
      final base = HomeSurface.localDefaults();
      final next = applyHomeUiEvent(
        base,
        HomeUiEvent.fromJson({
          'type': 'HOME_UI_GREETING',
          'version': '2026-07-15T13:00:00Z',
          'payload': {
            'id': 'g1',
            'text': 'Taxa Lightning menor hoje, {name}',
            'priority': 50,
            'animation': 'FADE',
          },
        }),
      );

      expect(next.header.greeting.mode, HomeGreetingMode.ticker);
      expect(next.header.greeting.activeMessages, hasLength(1));
      expect(
        next.header.greeting.activeMessages.first.resolveText('João'),
        'Taxa Lightning menor hoje, João',
      );
    });

    test('stale version events are dropped', () {
      final current = HomeSurface.localDefaults().copyWith(
        version: '2026-07-15T14:00:00Z',
      );
      final next = applyHomeUiEvent(
        current,
        HomeUiEvent.fromJson({
          'type': 'HOME_UI_PATCH',
          'version': '2026-07-15T13:00:00Z',
          'payload': {
            'header': {
              'actions': {
                'settings': {'visible': false},
              },
            },
          },
        }),
      );

      expect(next.header.actions.settings.visible, isTrue);
    });

    test('HOME_UI_SNAPSHOT replaces full state', () {
      final current = HomeSurface.localDefaults();
      final next = applyHomeUiEvent(
        current,
        HomeUiEvent.fromJson({
          'type': 'HOME_UI_SNAPSHOT',
          'version': 'snap-1',
          'payload': {
            'schemaVersion': 1,
            'version': 'snap-1',
            'ttlSeconds': 120,
            'balanceView': 'PLATFORM',
            'locale': 'en',
            'timeZone': 'UTC',
            'layout': {
              'sectionGapAfterHeader': 10,
              'sectionGapAfterBalance': 10,
              'sectionGapBeforeFeed': 10,
            },
            'header': {
              'greeting': {
                'mode': 'OVERRIDE',
                'fallback': {'template': 'TIME_OF_DAY', 'includeName': true},
                'messages': [
                  {'id': 'x', 'text': 'Hello {name}', 'priority': 1},
                ],
                'rotation': {'intervalMs': 4000, 'loop': true},
              },
              'actions': {
                'balanceVisibility': {'visible': false},
                'notifications': {'visible': true},
                'settings': {'visible': true},
              },
              'spacing': {'betweenActions': 8, 'afterGreeting': 12},
            },
            'feed': {
              'heightToken': 'compact',
              'items': [],
            },
          },
        }),
      );

      expect(next.version, 'snap-1');
      expect(next.header.greeting.mode, HomeGreetingMode.overrideMode);
      expect(next.header.actions.balanceVisibility.visible, isFalse);
      expect(next.feed.heightToken, HomeFeedHeightToken.compact);
      expect(next.feed.resolvedHeight, 120);
    });
  });
}
