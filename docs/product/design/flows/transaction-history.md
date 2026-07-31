# Flow: Transaction History

> Status: Draft | Applies-to: mobile · web
> Anchors: `lib/features/movement/presentation/activity/statement_transaction_card.dart`
> Last revised: 2026-07-31

## User objective chain

1. **Browse:** "What's happened recently?"
2. **Filter:** "Show me only [incoming/outgoing/Lightning/pending]"
3. **Inspect:** "What were the details of this transaction?"
4. **Act:** "Can I do something with this?" (copy tx ID, view explorer, repeat)

Success metric:
- Recent transactions visible at a glance
- Filters work without reload
- Detail shows everything relevant (amount, fee, status, confirmations, time)
- Block explorer accessible for on-chain transactions

---

## Screen sequence

```
Home (activity strip, last ~5 items)
  │
  └─→ Activity List (full screen)
        Entry: user taps "Ver todas" or activity tab
        Exit: user navigates to detail or back
        Dominant action: scroll list, tap row
        Secondary: filter chips (All, Incoming, Outgoing, Lightning, On-chain, Pending)
        Motion: push right (136ms easeOutQuart)
        States: loading (first load), empty, populated, filtered-empty, offline (last-known)
        │
        └─→ Transaction Detail
              Entry: user taps a transaction row
              Exit: user navigates back
              Dominant information: amount, counterparty, status, fee, time, tx ID
              Secondary actions: copy tx ID, view on explorer, repeat payment
              Motion: push right (136ms). Hero: transaction row → detail header.
              Continuity: amount + counterparty + status maintain position
              States: confirmed, pending, failed, cancelled
```

---

## State matrix

| State | Activity List | Transaction Detail |
|-------|-------------|-------------------|
| Loading | First load skeleton | — |
| Empty | "No transactions yet" + send action | — |
| Populated | List with items | Full detail |
| Filtered empty | "No [type] transactions" + clear filter | — |
| Error | Fetch failed, retry | Detail fetch failed |
| Offline | Last-known list + offline badge | Cached detail (if available) |
| Pending item | Item with pending badge | Detail shows confirmations / ETA |
| Failed item | Item with error badge | Detail shows failure reason |
| Cancelled item | Item with cancelled badge | Detail shows cancellation info |

---

## Continuity contracts

- **List row → Detail header:** Hero transition: amount + counterparty + status badge fly to detail header position
- **Detail → List:** Row returns to its original position. Scroll position preserved.
- **Filter chips:** Active filter persists across navigation. Filter change is instant (no list animation).

## Motion contract

- List → Detail: `KeroseneMotion.pageIn` (136ms) + Hero (260ms, easeOutExpo)
- Detail → List: `KeroseneMotion.pageOut` (92ms) + Hero reverse
- Filter change: instant state update, no list animation
- Pull-to-refresh: `BitcoinRefreshIndicator` (existing), preserve previous items

## Accessibility contract

- List rows: `semanticLabel: '{tipo}: {valor} — {status}. {data}.'`
- Status badges: icon + text label, never icon alone
- Filter chips: `semanticLabel: 'Filtrar por {tipo}'`, announce active filter on change

---

## Storybook coverage

| State | Story | Status |
|-------|-------|--------|
| Populated list | `Kerosene/App Flow` → `/history` | Exists |
| Empty list | Not covered | Gap |
| Filtered by type | Not covered | Gap |
| Pending transaction | Not covered | Gap |
| Failed transaction | Not covered | Gap |
| Offline list | Not covered | Gap |
