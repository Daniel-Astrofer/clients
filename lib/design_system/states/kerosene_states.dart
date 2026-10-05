/// Standardized state widgets for Kerosene screens.
///
/// Every screen must handle: loading, empty, error, offline.
/// These widgets provide the canonical implementations.
///
/// Usage:
/// ```dart
/// switch (state) {
///   case HomeState.loading:
///     return const KeroseneLoadingState(message: 'Carregando...');
///   case HomeState.empty:
///     return KeroseneEmptyState(
///       title: 'Nenhuma movimentacao',
///       actionLabel: 'Fazer primeiro envio',
///       onAction: () => context.push('/send'),
///     );
///   case HomeState.error:
///     return KeroseneErrorState(
///       title: 'Falha ao carregar',
///       message: 'Verifique sua conexao e tente novamente.',
///       onRetry: () => ref.invalidate(homeProvider),
///     );
/// }
/// ```
library;

export 'kerosene_loading_state.dart';
export 'kerosene_empty_state.dart';
export 'kerosene_error_state.dart';
export 'kerosene_offline_state.dart';
