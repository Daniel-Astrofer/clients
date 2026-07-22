import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/home_education_provider.dart';
import 'package:kerosene/features/home/scene/models/home_scene_mapper.dart';

void main() {
  test('incoming stage maps title+h2 subtitle', () {
    final stage = homeEducationToStage(
      const HomeEducationEvent(
        kind: HomeEducationKind.incomingTransfer,
        id: 'local-incoming-test',
        amountLabel: 'R\$ 10,00',
        walletName: 'Financeiro',
        networkLabel: 'Onchain',
      ),
      lang: 'pt',
    );
    expect(stage.isActive, isTrue);
    expect(stage.content.title, 'Recebido');
    expect(stage.content.hasRichBlocks, isTrue);
    final scene = homeSceneFromStage(stage);
    expect(scene.hasForegroundContent, isTrue);
    expect(scene.content.hasText, isTrue);
    expect(scene.content.title, 'Recebido');
    expect(scene.content.subtitle, contains('Transferência recebida'));
    expect(scene.content.subtitle, contains('R\$ 10,00'));
    print('OK title=${scene.content.title} sub=${scene.content.subtitle}');
  });
}
