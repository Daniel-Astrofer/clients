class MovementRoute {
  final String handlerId;
  final String routeName;
  final Object? extraArgs;
  final List<String> blockers;

  const MovementRoute({
    required this.handlerId,
    required this.routeName,
    this.extraArgs,
    this.blockers = const [],
  });

  bool get canContinue => blockers.isEmpty;
}
