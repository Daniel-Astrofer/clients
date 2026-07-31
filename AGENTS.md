# Agent rules

## Truth sources (ordered)
1. `docs/product/design/README.md` — Design Operating System index
2. `docs/DESIGN_SYSTEM.md` — Design system token authority
3. `docs/KEROSENE_FRONTEND_ARCHITECTURE.md` — Layer architecture contract
4. `docs/STORYBOOK_SCREEN_INVENTORY.md` — Screen & story coverage
5. `docs/agents/UI_FEATURE_AGENT.md` — Frontend agent prompt & checklist

## Rules
- Keep protocol parsing and quorum verification in shared packages.
- Consume versioned `kerosene-contracts` artifacts.
- Never commit user snapshots, balances, credentials, seeds or signing keys.
- Run Flutter analyze and relevant tests before pushing.
- Preserve platform parity unless a platform-specific limitation is documented.
- Large binary assets should use Git LFS in a dedicated migration.
