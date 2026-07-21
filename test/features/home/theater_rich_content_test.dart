import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/presentation/providers/theater_catalog.dart';
import 'package:kerosene/features/home/presentation/providers/theater_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TheaterTextBlock / HomeStageContent rich parse', () {
    test('parses blocks, spans and roles from JSON', () {
      final content = HomeStageContent.fromJson({
        'title': 'O que é a blockchain? 🔗',
        'textMode': 'STATIC',
        'blocks': [
          {'role': 'H2', 'text': 'Um livro público', 'emoji': '📖'},
          {
            'role': 'BODY',
            'text': 'A blockchain é uma cadeia de blocos.',
            'spans': [
              {'start': 2, 'end': 12, 'weight': 'BOLD'},
            ],
          },
          {'role': 'BULLET', 'text': 'Auditável', 'emoji': '✅'},
          {'role': 'CAPTION', 'text': 'Toque para saber mais.'},
        ],
      });

      expect(content.hasRichBlocks, isTrue);
      expect(content.blocks, hasLength(4));
      expect(content.blocks[0].role, TheaterBlockRole.h2);
      expect(content.blocks[0].emoji, '📖');
      expect(content.blocks[1].spans, hasLength(1));
      expect(content.blocks[1].spans.first.weight, TheaterTextWeight.bold);
      expect(content.plainBodyFallback(), contains('Um livro público'));
      expect(content.plainBodyFallback(), contains('Auditável'));
    });

    test('round-trips blocks in toJson', () {
      const original = HomeStageContent(
        title: 'T',
        blocks: [
          TheaterTextBlock(
            role: TheaterBlockRole.h2,
            text: 'Sub',
            emoji: '🧱',
          ),
          TheaterTextBlock(
            role: TheaterBlockRole.body,
            text: 'Hello world',
            spans: [
              TheaterTextSpanMark(
                  start: 0, end: 5, weight: TheaterTextWeight.bold),
            ],
          ),
        ],
      );
      final again = HomeStageContent.fromJson(original.toJson());
      expect(again.blocks, hasLength(2));
      expect(again.blocks[1].spans.first.end, 5);
    });
  });

  group('theater catalog + education stage', () {
    test('catalog includes blockchain pilot with rich copy', () {
      final piece = theaterPieceById('learn-blockchain-01');
      expect(piece, isNotNull);
      final copy = piece!.copyFor('pt');
      expect(copy.title, contains('blockchain'));
      expect(copy.blocks.any((b) => b.role == TheaterBlockRole.h2), isTrue);
      expect(copy.blocks.any((b) => b.role == TheaterBlockRole.bullet), isTrue);
    });

    test('homeEducationToStage builds active rich feature stage', () {
      final stage = homeEducationToStage(
        const HomeEducationEvent(
          kind: HomeEducationKind.educationTip,
          id: 'local-edu-learn-blockchain-01',
          catalogPieceId: 'learn-blockchain-01',
        ),
        lang: 'pt',
      );
      expect(stage.isActive, isTrue);
      expect(stage.kind, HomeStageKind.feature);
      expect(stage.content.hasRichBlocks, isTrue);
      expect(stage.atmosphere.hasGlows, isTrue);
      expect(stage.priority, 80);
    });
  });

  group('TheaterScheduler', () {
    test('picks a piece when idle and budget allows', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final piece = pickNextTheaterPiece(
        prefs: prefs,
        context: const TheaterSchedulerContext(
          userId: 'u1',
          idleFor: Duration(seconds: 60),
        ),
        session: const TheaterSchedulerState(),
      );
      expect(piece, isNotNull);
    });

    test('respects session budget', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final piece = pickNextTheaterPiece(
        prefs: prefs,
        context: const TheaterSchedulerContext(
          userId: 'u1',
          idleFor: Duration(seconds: 60),
        ),
        session: const TheaterSchedulerState(
          educationPresentedThisSession: 2,
        ),
      );
      expect(piece, isNull);
    });

    test('respects piece cooldown after mark shown', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = pickNextTheaterPiece(
        prefs: prefs,
        context: const TheaterSchedulerContext(
          userId: 'u1',
          idleFor: Duration(seconds: 60),
        ),
        session: const TheaterSchedulerState(),
      )!;
      await markTheaterPieceShown(
        prefs: prefs,
        userId: 'u1',
        piece: first,
      );
      // Same piece must not win immediately; family cooldown may also block learn.
      final second = pickNextTheaterPiece(
        prefs: prefs,
        context: const TheaterSchedulerContext(
          userId: 'u1',
          idleFor: Duration(seconds: 60),
        ),
        session: TheaterSchedulerState(
          educationPresentedThisSession: 1,
          lastEducationAt: DateTime.now().subtract(const Duration(minutes: 5)),
          lastFamily: first.family,
        ),
      );
      if (second != null) {
        expect(second.id, isNot(first.id));
      }
    });

    test('blocks while high priority busy', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final piece = pickNextTheaterPiece(
        prefs: prefs,
        context: const TheaterSchedulerContext(
          userId: 'u1',
          highPriorityBusy: true,
          idleFor: Duration(seconds: 120),
        ),
        session: const TheaterSchedulerState(),
      );
      expect(piece, isNull);
    });
  });
}
