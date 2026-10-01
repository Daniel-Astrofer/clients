# Cell operator presentation boundary

The Dashboard ReleaseCard mounts CellOperationsCard, which consumes Core-only
AdminDataService requests through the existing authenticated ApiClient. Riverpod
owns snapshot refresh and update-plan history. CellOperationsView checks missing
schema, signatures, freshness, quorum, backup restore evidence and KFE maintenance
before presenting readiness. The browser holds no Bank/KFE mTLS credentials and
has no deployment or database integration.

The only mutation is an audited Core request to record a target-bound plan. Bank
evidence owns actual update phase/history. Plans never mutate that history or
claim execution. See [product behavior and accessibility](../product/CELL_OPERATIONS.md).
