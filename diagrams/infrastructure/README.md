# Infrastructure diagrams

The infrastructure views are rendered from Mermaid in Markdown:

- [Platform architecture](platform.md)
- [Deployment and service map](deployments.md)
- [Infrastructure delivery](delivery.md)
- [Recovery decision flow](recovery.md)

Compact versions also appear in the [architecture overview](../../docs/overview.md), [root project overview](../../README.md#architecture-at-a-glance), and [backup strategy](../../docs/backup-strategy.md).

Use this directory if a future diagram needs a format Mermaid cannot express. Commit the editable source together with a GitHub-viewable export, and state which one is authoritative.

Useful conventions:

| Type | Color |
| --- | --- |
| Compute | Blue |
| Storage | Orange |
| Network | Green |
| Security boundary | Red |
| External service | Gray |

Avoid turning a diagram into an inventory dump. A useful infrastructure view should make a dependency, trust boundary, or failure domain clearer than the accompanying text.
