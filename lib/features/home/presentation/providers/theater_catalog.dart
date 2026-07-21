import 'package:kerosene/features/home/domain/entities/home_stage.dart';
import 'package:kerosene/features/home/presentation/providers/theater_atmosphere_presets.dart';

/// Family for cooldown grouping (one learn tip / 24h, etc.).
enum TheaterPieceFamily {
  learn,
  product,
  security,
  contextual,
  market,
}

/// Static offline catalog entry for recurring education theater.
class TheaterCatalogPiece {
  final String id;
  final TheaterPieceFamily family;
  final int priority;
  final Duration cooldown;
  final TheaterAtmospherePreset atmosphere;
  final int showDurationMs;
  final HomeStageCta? cta;

  /// Optional context tags: cold, onchain, platform, noTotp, hasWallet…
  final Set<String> contextTags;

  const TheaterCatalogPiece({
    required this.id,
    required this.family,
    this.priority = 80,
    this.cooldown = const Duration(days: 5),
    this.atmosphere = TheaterAtmospherePreset.learn,
    this.showDurationMs = 15000,
    this.cta,
    this.contextTags = const {},
  });

  /// Localized rich content for [lang] (`pt` / `en` / `es`).
  ///
  /// Accepts full locale tags (`pt_BR`, `en-US`) — Linux desktops often pass those.
  TheaterLocalizedCopy copyFor(String lang) {
    final table = _catalogCopy[id];
    if (table == null) {
      return const TheaterLocalizedCopy(
        title: 'Kerosene',
        blocks: [
          TheaterTextBlock(role: TheaterBlockRole.body, text: ''),
        ],
      );
    }
    final key = lang.trim().toLowerCase().split(RegExp(r'[_-]')).first;
    return table[key] ?? table['pt'] ?? table.values.first;
  }
}

class TheaterLocalizedCopy {
  final String title;
  final List<TheaterTextBlock> blocks;

  const TheaterLocalizedCopy({
    required this.title,
    required this.blocks,
  });
}

/// Full local catalog (phase 1). Content is primarily pt-BR; en/es included for core set.
List<TheaterCatalogPiece> get theaterCatalog => _pieces;

const _pieces = <TheaterCatalogPiece>[
  // ── Learn ──────────────────────────────────────────────────────────────
  TheaterCatalogPiece(
    id: 'learn-blockchain-01',
    family: TheaterPieceFamily.learn,
    priority: 80,
    cooldown: Duration(days: 5),
    atmosphere: TheaterAtmospherePreset.learn,
  ),
  TheaterCatalogPiece(
    id: 'learn-block-02',
    family: TheaterPieceFamily.learn,
    priority: 80,
    cooldown: Duration(days: 5),
    atmosphere: TheaterAtmospherePreset.bitcoin,
  ),
  TheaterCatalogPiece(
    id: 'learn-tx-03',
    family: TheaterPieceFamily.learn,
    priority: 80,
    cooldown: Duration(days: 5),
    atmosphere: TheaterAtmospherePreset.bitcoin,
  ),
  TheaterCatalogPiece(
    id: 'learn-utxo-04',
    family: TheaterPieceFamily.learn,
    priority: 80,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.learn,
  ),
  TheaterCatalogPiece(
    id: 'learn-conf-05',
    family: TheaterPieceFamily.learn,
    priority: 80,
    cooldown: Duration(days: 5),
    atmosphere: TheaterAtmospherePreset.bitcoin,
    contextTags: {'onchain', 'cold'},
  ),
  TheaterCatalogPiece(
    id: 'learn-fees-06',
    family: TheaterPieceFamily.learn,
    priority: 80,
    cooldown: Duration(days: 5),
    atmosphere: TheaterAtmospherePreset.bitcoin,
    contextTags: {'onchain', 'cold'},
  ),
  TheaterCatalogPiece(
    id: 'learn-mempool-07',
    family: TheaterPieceFamily.learn,
    priority: 80,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.bitcoin,
    contextTags: {'onchain', 'cold'},
  ),
  TheaterCatalogPiece(
    id: 'learn-keys-08',
    family: TheaterPieceFamily.learn,
    priority: 85,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.security,
  ),
  TheaterCatalogPiece(
    id: 'learn-seed-09',
    family: TheaterPieceFamily.learn,
    priority: 90,
    cooldown: Duration(days: 10),
    atmosphere: TheaterAtmospherePreset.security,
    contextTags: {'cold'},
  ),
  TheaterCatalogPiece(
    id: 'learn-lightning-10',
    family: TheaterPieceFamily.learn,
    priority: 80,
    cooldown: Duration(days: 5),
    atmosphere: TheaterAtmospherePreset.lightning,
  ),
  TheaterCatalogPiece(
    id: 'learn-self-custody-11',
    family: TheaterPieceFamily.learn,
    priority: 85,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.learn,
    contextTags: {'cold'},
  ),
  TheaterCatalogPiece(
    id: 'learn-sats-12',
    family: TheaterPieceFamily.learn,
    priority: 70,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.bitcoin,
  ),
  // ── Product ────────────────────────────────────────────────────────────
  TheaterCatalogPiece(
    id: 'prod-wallets-kinds',
    family: TheaterPieceFamily.product,
    priority: 85,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.brand,
    contextTags: {'hasWallet'},
  ),
  TheaterCatalogPiece(
    id: 'prod-extrato',
    family: TheaterPieceFamily.product,
    priority: 80,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.brand,
  ),
  TheaterCatalogPiece(
    id: 'prod-receive',
    family: TheaterPieceFamily.product,
    priority: 80,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.positive,
  ),
  TheaterCatalogPiece(
    id: 'prod-send-rails',
    family: TheaterPieceFamily.product,
    priority: 80,
    cooldown: Duration(days: 7),
    atmosphere: TheaterAtmospherePreset.lightning,
  ),
  TheaterCatalogPiece(
    id: 'prod-pending',
    family: TheaterPieceFamily.product,
    priority: 85,
    cooldown: Duration(days: 5),
    atmosphere: TheaterAtmospherePreset.bitcoin,
    contextTags: {'onchain', 'cold'},
  ),
  TheaterCatalogPiece(
    id: 'prod-tor',
    family: TheaterPieceFamily.product,
    priority: 75,
    cooldown: Duration(days: 14),
    atmosphere: TheaterAtmospherePreset.security,
  ),
  TheaterCatalogPiece(
    id: 'prod-cards',
    family: TheaterPieceFamily.product,
    priority: 70,
    cooldown: Duration(days: 14),
    atmosphere: TheaterAtmospherePreset.brand,
  ),
  // ── Security ───────────────────────────────────────────────────────────
  TheaterCatalogPiece(
    id: 'sec-phishing',
    family: TheaterPieceFamily.security,
    priority: 95,
    cooldown: Duration(days: 10),
    atmosphere: TheaterAtmospherePreset.security,
  ),
  TheaterCatalogPiece(
    id: 'sec-sessions',
    family: TheaterPieceFamily.security,
    priority: 85,
    cooldown: Duration(days: 14),
    atmosphere: TheaterAtmospherePreset.security,
    cta: HomeStageCta(
      label: 'Ver segurança',
      action: 'NAVIGATE',
      target: '/settings/security',
    ),
  ),
  TheaterCatalogPiece(
    id: 'sec-backup',
    family: TheaterPieceFamily.security,
    priority: 90,
    cooldown: Duration(days: 14),
    atmosphere: TheaterAtmospherePreset.security,
    contextTags: {'cold'},
  ),
  TheaterCatalogPiece(
    id: 'sec-pin',
    family: TheaterPieceFamily.security,
    priority: 80,
    cooldown: Duration(days: 14),
    atmosphere: TheaterAtmospherePreset.security,
  ),
  // ── Market soft ────────────────────────────────────────────────────────
  TheaterCatalogPiece(
    id: 'market-volatility',
    family: TheaterPieceFamily.market,
    priority: 60,
    cooldown: Duration(days: 14),
    atmosphere: TheaterAtmospherePreset.brand,
    showDurationMs: 12000,
  ),
];

TheaterCatalogPiece? theaterPieceById(String id) {
  for (final p in _pieces) {
    if (p.id == id) return p;
  }
  return null;
}

// ── Copy tables ────────────────────────────────────────────────────────────

TheaterTextBlock _h2(String text, {String? emoji}) =>
    TheaterTextBlock(role: TheaterBlockRole.h2, text: text, emoji: emoji);

TheaterTextBlock _body(String text,
        {List<TheaterTextSpanMark> spans = const []}) =>
    TheaterTextBlock(role: TheaterBlockRole.body, text: text, spans: spans);

TheaterTextBlock _bullet(String text, {String? emoji}) =>
    TheaterTextBlock(role: TheaterBlockRole.bullet, text: text, emoji: emoji);

TheaterTextBlock _caption(String text) =>
    TheaterTextBlock(role: TheaterBlockRole.caption, text: text);

TheaterTextSpanMark _bold(int start, int end) =>
    TheaterTextSpanMark(start: start, end: end, weight: TheaterTextWeight.bold);

/// Bold range helper: finds first occurrence of [needle] in [hay].
TheaterTextSpanMark? _boldOf(String hay, String needle) {
  final i = hay.indexOf(needle);
  if (i < 0) return null;
  return _bold(i, i + needle.length);
}

List<TheaterTextSpanMark> _bolds(String hay, List<String> needles) {
  final out = <TheaterTextSpanMark>[];
  for (final n in needles) {
    final m = _boldOf(hay, n);
    if (m != null) out.add(m);
  }
  return out;
}

Map<String, TheaterLocalizedCopy> _loc({
  required String ptTitle,
  required List<TheaterTextBlock> ptBlocks,
  String? enTitle,
  List<TheaterTextBlock>? enBlocks,
  String? esTitle,
  List<TheaterTextBlock>? esBlocks,
}) {
  return {
    'pt': TheaterLocalizedCopy(title: ptTitle, blocks: ptBlocks),
    if (enTitle != null && enBlocks != null)
      'en': TheaterLocalizedCopy(title: enTitle, blocks: enBlocks),
    if (esTitle != null && esBlocks != null)
      'es': TheaterLocalizedCopy(title: esTitle, blocks: esBlocks),
  };
}

final Map<String, Map<String, TheaterLocalizedCopy>> _catalogCopy = {
  'learn-blockchain-01': _loc(
    ptTitle: 'O que é a blockchain? 🔗',
    ptBlocks: [
      _h2('Um livro que todos podem ler', emoji: '📖'),
      _body(
        'A blockchain é uma cadeia de blocos — pense num caderno público: cada página é um bloco, e as páginas se encadeiam.',
        spans: _bolds(
          'A blockchain é uma cadeia de blocos — pense num caderno público: cada página é um bloco, e as páginas se encadeiam.',
          ['cadeia de blocos', 'caderno público'],
        ),
      ),
      _bullet('Ninguém apaga o que já entrou', emoji: '✅'),
      _bullet('Qualquer um pode verificar', emoji: '👁️'),
      _caption('Bitcoin roda nessa ideia — aberta e auditável.'),
    ],
    enTitle: 'What is a blockchain? 🔗',
    enBlocks: [
      _h2('A book anyone can read', emoji: '📖'),
      _body(
        'A blockchain is a chain of blocks — think of a public notebook: each page is a block, and pages link together.',
        spans: _bolds(
          'A blockchain is a chain of blocks — think of a public notebook: each page is a block, and pages link together.',
          ['chain of blocks', 'public notebook'],
        ),
      ),
      _bullet('No one erases what already landed', emoji: '✅'),
      _bullet('Anyone can verify', emoji: '👁️'),
    ],
    esTitle: '¿Qué es la blockchain? 🔗',
    esBlocks: [
      _h2('Un libro que todos pueden leer', emoji: '📖'),
      _body(
        'La blockchain es una cadena de bloques — un cuaderno público: cada página es un bloque y se encadenan.',
        spans: _bolds(
          'La blockchain es una cadena de bloques — un cuaderno público: cada página es un bloque y se encadenan.',
          ['cadena de bloques', 'cuaderno público'],
        ),
      ),
      _bullet('Nadie borra lo que ya entró', emoji: '✅'),
      _bullet('Cualquiera puede verificar', emoji: '👁️'),
    ],
  ),
  'learn-block-02': _loc(
    ptTitle: 'O que é um bloco? 🧱',
    ptBlocks: [
      _h2('Uma página do caderno', emoji: '📄'),
      _body(
        'Cada bloco agrupa várias transações e um selo de tempo. O próximo bloco aponta para o anterior — por isso é uma cadeia.',
        spans: _bolds(
          'Cada bloco agrupa várias transações e um selo de tempo. O próximo bloco aponta para o anterior — por isso é uma cadeia.',
          ['agrupa várias transações', 'cadeia'],
        ),
      ),
      _bullet('Mais blocos = mais difícil reescrever o passado', emoji: '🔒'),
    ],
  ),
  'learn-tx-03': _loc(
    ptTitle: 'O que é uma transação? 📤',
    ptBlocks: [
      _h2('Um movimento de valor', emoji: '💸'),
      _body(
        'Uma transação diz: “estes bitcoins saem daqui e vão para ali”, com uma assinatura digital que prova o direito de gastar.',
        spans: _bolds(
          'Uma transação diz: “estes bitcoins saem daqui e vão para ali”, com uma assinatura digital que prova o direito de gastar.',
          ['assinatura digital'],
        ),
      ),
      _bullet('No extrato você vê cada movimento', emoji: '📋'),
    ],
  ),
  'learn-utxo-04': _loc(
    ptTitle: 'UTXO em uma frase 🪙',
    ptBlocks: [
      _h2('Notas digitais não gastas', emoji: '💵'),
      _body(
        'UTXO = “unspent transaction output”. Sua carteira soma pedaços de bitcoin ainda não gastos — como notas na carteira física.',
        spans: _bolds(
          'UTXO = “unspent transaction output”. Sua carteira soma pedaços de bitcoin ainda não gastos — como notas na carteira física.',
          ['ainda não gastos'],
        ),
      ),
    ],
  ),
  'learn-conf-05': _loc(
    ptTitle: 'Confirmações 0 → 6 ⏳',
    ptBlocks: [
      _h2('Quanto tempo a rede “fecha” o acordo', emoji: '⏱️'),
      _body(
        '0 confirmações = na mempool (ainda pode reordenar). Cada novo bloco soma 1. Em ~6 a maioria trata como bem solidificado.',
        spans: _bolds(
          '0 confirmações = na mempool (ainda pode reordenar). Cada novo bloco soma 1. Em ~6 a maioria trata como bem solidificado.',
          ['0 confirmações', '~6'],
        ),
      ),
      _bullet('No app, os anéis mostram o progresso', emoji: '⭕'),
    ],
  ),
  'learn-fees-06': _loc(
    ptTitle: 'Taxas de rede ⚡',
    ptBlocks: [
      _h2('Pagar para caber no próximo bloco', emoji: '📦'),
      _body(
        'Miners escolhem txs com melhor taxa por byte. Em horários cheios, pagar um pouco mais acelera a confirmação.',
        spans: _bolds(
          'Miners escolhem txs com melhor taxa por byte. Em horários cheios, pagar um pouco mais acelera a confirmação.',
          ['taxa por byte'],
        ),
      ),
    ],
  ),
  'learn-mempool-07': _loc(
    ptTitle: 'O que é a mempool? 🌊',
    ptBlocks: [
      _h2('Sala de espera da rede', emoji: '🚪'),
      _body(
        'Antes de entrar num bloco, a transação fica na mempool — um pool de txs conhecidas pelos nós, ainda não mineradas.',
        spans: _bolds(
          'Antes de entrar num bloco, a transação fica na mempool — um pool de txs conhecidas pelos nós, ainda não mineradas.',
          ['mempool'],
        ),
      ),
      _bullet('Pendente no extrato costuma ser mempool', emoji: '⏳'),
    ],
  ),
  'learn-keys-08': _loc(
    ptTitle: 'Chaves e assinatura 🔑',
    ptBlocks: [
      _h2('Prova sem revelar o segredo', emoji: '✍️'),
      _body(
        'A chave privada assina; a pública verifica. Quem tem a privada controla os fundos — por isso nunca compartilhe seed ou chave.',
        spans: _bolds(
          'A chave privada assina; a pública verifica. Quem tem a privada controla os fundos — por isso nunca compartilhe seed ou chave.',
          ['chave privada', 'nunca compartilhe'],
        ),
      ),
    ],
  ),
  'learn-seed-09': _loc(
    ptTitle: 'Sua seed é o cofre 🌱',
    ptBlocks: [
      _h2('12 ou 24 palavras = recuperação', emoji: '📝'),
      _body(
        'A frase de recuperação recria as chaves. Anote offline, guarde seguro e nunca digite em sites ou apps desconhecidos.',
        spans: _bolds(
          'A frase de recuperação recria as chaves. Anote offline, guarde seguro e nunca digite em sites ou apps desconhecidos.',
          ['Anote offline', 'nunca digite'],
        ),
      ),
      _bullet('Kerosene nunca pede sua seed', emoji: '🛡️'),
    ],
  ),
  'learn-lightning-10': _loc(
    ptTitle: 'Lightning vs on-chain ⚡',
    ptBlocks: [
      _h2('Dois jeitos de mover bitcoin', emoji: '🛤️'),
      _body(
        'On-chain é o livro principal (mais lento, mais final). Lightning é rede de pagamento rápida por cima — ideal para valores menores.',
        spans: _bolds(
          'On-chain é o livro principal (mais lento, mais final). Lightning é rede de pagamento rápida por cima — ideal para valores menores.',
          ['On-chain', 'Lightning'],
        ),
      ),
    ],
  ),
  'learn-self-custody-11': _loc(
    ptTitle: 'Custódia e cold wallet 🧊',
    ptBlocks: [
      _h2('Quem segura as chaves?', emoji: '🗝️'),
      _body(
        'Carteira fria (cold) observa a cadeia: o saldo é o que a rede vê. Você controla as chaves; a plataforma não gasta por você.',
        spans: _bolds(
          'Carteira fria (cold) observa a cadeia: o saldo é o que a rede vê. Você controla as chaves; a plataforma não gasta por você.',
          ['o que a rede vê', 'controla as chaves'],
        ),
      ),
    ],
  ),
  'learn-sats-12': _loc(
    ptTitle: 'O que são satoshis? 🟠',
    ptBlocks: [
      _h2('A menor unidade do bitcoin', emoji: '🔬'),
      _body(
        '1 BTC = 100.000.000 sats. Pensar em sats ajuda em valores pequenos — como centavos do real.',
        spans: _bolds(
          '1 BTC = 100.000.000 sats. Pensar em sats ajuda em valores pequenos — como centavos do real.',
          ['100.000.000 sats'],
        ),
      ),
    ],
  ),
  'prod-wallets-kinds': _loc(
    ptTitle: 'Três jeitos de guardar 💼',
    ptBlocks: [
      _h2('Interna · Custodial · Cold', emoji: '🗂️'),
      _body(
        'Interna move valor na plataforma. Custodial on-chain usa a rede com a Kerosene. Cold é watch-only: você assina fora.',
        spans: _bolds(
          'Interna move valor na plataforma. Custodial on-chain usa a rede com a Kerosene. Cold é watch-only: você assina fora.',
          ['Interna', 'Custodial', 'Cold'],
        ),
      ),
    ],
  ),
  'prod-extrato': _loc(
    ptTitle: 'O extrato é a verdade 📋',
    ptBlocks: [
      _h2('Cada crédito e débito', emoji: '📊'),
      _body(
        'O extrato lista movimentos com status e confirmações. Pendente não some — está aguardando a rede ou liquidação interna.',
        spans: _bolds(
          'O extrato lista movimentos com status e confirmações. Pendente não some — está aguardando a rede ou liquidação interna.',
          ['Pendente não some'],
        ),
      ),
    ],
  ),
  'prod-receive': _loc(
    ptTitle: 'Como receber com calma 📥',
    ptBlocks: [
      _h2('Endereço ou cobrança', emoji: '🏷️'),
      _body(
        'Gere um endereço ou link na carteira certa. On-chain pode levar minutos; Lightning e interno costumam ser quase instantâneos.',
        spans: _bolds(
          'Gere um endereço ou link na carteira certa. On-chain pode levar minutos; Lightning e interno costumam ser quase instantâneos.',
          ['carteira certa'],
        ),
      ),
    ],
  ),
  'prod-send-rails': _loc(
    ptTitle: 'Escolher a rede 🛤️',
    ptBlocks: [
      _h2('Rápido ou final?', emoji: '⚖️'),
      _body(
        'Lightning e interno: velocidade. On-chain: liquidação na blockchain — use quando a contraparte pede endereço BTC.',
        spans: _bolds(
          'Lightning e interno: velocidade. On-chain: liquidação na blockchain — use quando a contraparte pede endereço BTC.',
          ['velocidade', 'blockchain'],
        ),
      ),
    ],
  ),
  'prod-pending': _loc(
    ptTitle: 'Pendente ≠ perdido ⏳',
    ptBlocks: [
      _h2('Aguarde a rede', emoji: '🌊'),
      _body(
        'Depósitos on-chain começam pendentes (mempool). Conforme os blocos chegam, as confirmações sobem e o status solidifica.',
        spans: _bolds(
          'Depósitos on-chain começam pendentes (mempool). Conforme os blocos chegam, as confirmações sobem e o status solidifica.',
          ['pendentes', 'confirmações'],
        ),
      ),
    ],
  ),
  'prod-tor': _loc(
    ptTitle: 'Por que usamos Tor? 🧅',
    ptBlocks: [
      _h2('Privacidade de caminho', emoji: '🛡️'),
      _body(
        'O app fala com a plataforma via Tor para reduzir rastros de rede. Pode demorar um pouco na primeira conexão — é normal.',
        spans: _bolds(
          'O app fala com a plataforma via Tor para reduzir rastros de rede. Pode demorar um pouco na primeira conexão — é normal.',
          ['via Tor'],
        ),
      ),
    ],
  ),
  'prod-cards': _loc(
    ptTitle: 'Cartões Kerosene ✨',
    ptBlocks: [
      _h2('Bronze · White · Black', emoji: '💳'),
      _body(
        'Cada nível tem taxa externa diferente. O cartão sobe com tempo de conta e movimentação mensal — as regras e percentuais vêm da plataforma.',
        spans: _bolds(
          'Cada nível tem taxa externa diferente. O cartão sobe com tempo de conta e movimentação mensal — as regras e percentuais vêm da plataforma.',
          ['taxa externa', 'tempo de conta', 'movimentação mensal'],
        ),
      ),
    ],
  ),
  'sec-phishing': _loc(
    ptTitle: 'Nunca peça a seed 🚨',
    ptBlocks: [
      _h2('Golpe clássico', emoji: '🎣'),
      _body(
        'Suporte legítimo nunca pede frase de recuperação, PIN completo ou códigos de autenticação por chat. Desconfie e ignore.',
        spans: _bolds(
          'Suporte legítimo nunca pede frase de recuperação, PIN completo ou códigos de autenticação por chat. Desconfie e ignore.',
          ['nunca pede'],
        ),
      ),
    ],
  ),
  'sec-sessions': _loc(
    ptTitle: 'Revise sessões ativas 👁️',
    ptBlocks: [
      _h2('Só você deve estar dentro', emoji: '🖥️'),
      _body(
        'Se vir um login estranho, encerre sessões em Configurações → Segurança e troque a senha. TOTP deixa isso bem mais forte.',
        spans: _bolds(
          'Se vir um login estranho, encerre sessões em Configurações → Segurança e troque a senha. TOTP deixa isso bem mais forte.',
          ['Configurações → Segurança', 'TOTP'],
        ),
      ),
    ],
  ),
  'sec-backup': _loc(
    ptTitle: 'Backup da cold wallet 🧊',
    ptBlocks: [
      _h2('Seed fora da nuvem', emoji: '📦'),
      _body(
        'Guarde a seed em local físico seguro. Sem ela, fundos da cold não se recuperam se o dispositivo sumir.',
        spans: _bolds(
          'Guarde a seed em local físico seguro. Sem ela, fundos da cold não se recuperam se o dispositivo sumir.',
          ['local físico seguro'],
        ),
      ),
    ],
  ),
  'sec-pin': _loc(
    ptTitle: 'PIN do app 🔐',
    ptBlocks: [
      _h2('Trava local', emoji: '📱'),
      _body(
        'O PIN protege o app neste aparelho. Combine com biometria e TOTP para camadas diferentes de defesa.',
        spans: _bolds(
          'O PIN protege o app neste aparelho. Combine com biometria e TOTP para camadas diferentes de defesa.',
          ['PIN', 'TOTP'],
        ),
      ),
    ],
  ),
  'market-volatility': _loc(
    ptTitle: 'O preço mexe — e tudo bem 📈',
    ptBlocks: [
      _h2('Volatilidade é do jogo', emoji: '🌊'),
      _body(
        'Variações de preço em 24h são comuns. O teatro mostra o mercado; não é recomendação de compra ou venda.',
        spans: _bolds(
          'Variações de preço em 24h são comuns. O teatro mostra o mercado; não é recomendação de compra ou venda.',
          ['não é recomendação'],
        ),
      ),
    ],
  ),
};
