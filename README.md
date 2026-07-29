# Kerosene Clients

Flutter clients and shared client-side packages for Kerosene.

This repository contains consumer and business surfaces, the design system,
API clients, protocol serialization and quorum/receipt verification. Android,
Windows, Linux and Web remain together because they share a toolchain and
change as one client product family.

Extracted from `Daniel-Astrofer/Kerosene` with frontend history preserved.

`flutter analyze` and the full test suite are staged off in the first CI
snapshot because `Kerosene/main` contains an existing analysis baseline. They
must be re-enabled after the frontend recovery changes are merged and imported.
