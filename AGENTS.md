# Agent rules

- Keep protocol parsing and quorum verification in shared packages.
- Consume versioned `kerosene-contracts` artifacts.
- Never commit user snapshots, balances, credentials, seeds or signing keys.
- Run Flutter analyze and relevant tests before pushing.
- Preserve platform parity unless a platform-specific limitation is documented.
- Large binary assets should use Git LFS in a dedicated migration.
