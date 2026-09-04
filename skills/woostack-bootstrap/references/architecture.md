# Architecture & Code Placement

Application code starts in the deployable unit that owns it. Shared code is created only when
multiple applications need the same implementation or contract.

## Repository-native placement

- Existing repository structure and naming are authoritative.
- In a new repository, use the approved stack's native structure; do not impose a second layout.
- Create only the directories and modules required by the approved product.
- Keep business logic, data access, authentication, observability, UI, utilities, and vendor
  integrations with the application that owns them.

## App-local first

- Extract only the smallest coherent surface genuinely shared by multiple applications.
- Name and place shared code according to the repository's conventions and the capability it owns.
- After extraction, keep one implementation and remove application-local duplicates.
- Do not create empty shared locations, placeholder packages, or wrapper manifests.

## Application boundaries

Boundary adapters map wire or vendor data to application/domain models, isolate transport errors,
and validate untrusted input when applications communicate. Keep them with the application that owns
the boundary unless multiple applications genuinely share the exact contract or implementation.
See [Application-boundary adapters](patterns.md#3-application-boundary-adapters).

## Mixed-technology repositories

When approved requirements call for multiple technologies:

- Follow each deployable unit's native structure and dependency manifest.
- Add root orchestration only when it simplifies real cross-application commands.
- Use an approved technology-neutral contract representation when unlike applications must share a
  boundary contract.
