# Infrastructure delivery flow

Most deployments use the reviewed path on the left. Runner provisioning and deliberate replacement are exceptional paths with additional safeguards.

```mermaid
flowchart TB
    Change["Focused change"] --> Local["Local formatting + checks"]
    Local --> PR["Pull request"]
    PR --> Detect["Detect changed deployment tiers"]
    Detect --> CI["Reusable Terraform CI"]
    CI --> Validate["Init + validate"]
    Validate --> Secrets["Resolve secret identifiers"]
    Secrets --> Plan["Create saved plan"]
    Plan --> Summary["Post plan summary"]
    Plan --> Artifact[("Encrypted plan artifact")]
    Summary --> Review{"Plan matches intent?"}

    Review -->|no| Revise["Revise configuration"]
    Revise --> Local
    Review -->|yes| Merge["Merge to main"]
    Merge --> Gate{"Push to main?"}
    Gate -->|yes| Apply["Apply saved plan"]
    Artifact --> Apply
    Apply --> Verify["Verify Proxmox, guest,<br/>network, and service"]
    Gate -->|no| Stop["No apply"]

    Manual["Manual runner dispatch"] --> DryRun{"dry_run enabled?"}
    DryRun -->|yes| RunnerPlan["Mint short-lived tokens<br/>and inspect plan"]
    DryRun -->|no| Guard["Reject deletes +<br/>duplicate registrations"]
    RunnerPlan --> Decision{"Operator approves?"}
    Decision -->|yes, dispatch again| Guard
    Decision -->|no| Stop
    Guard --> RunnerApply["Apply runner plan"]
    RunnerApply --> Verify

    Replace["Manual replacement dispatch"] --> Exact["Resolve exact resource address"]
    Exact --> Backup{"Backup and recovery<br/>path confirmed?"}
    Backup -->|no| Stop
    Backup -->|yes| FreshPlan["Print fresh replacement plan"]
    FreshPlan --> ReplaceApply["Auto-approved replacement"]
    ReplaceApply --> Verify

    classDef input fill:#8250df,stroke:#6639ba,color:#fff;
    classDef check fill:#0969da,stroke:#0550ae,color:#fff;
    classDef decision fill:#bf8700,stroke:#9a6700,color:#fff;
    classDef action fill:#1a7f37,stroke:#116329,color:#fff;
    classDef danger fill:#cf222e,stroke:#a40e26,color:#fff;
    classDef artifact fill:#57606a,stroke:#424a53,color:#fff;

    class Change,Manual,Replace input;
    class Local,PR,Detect,CI,Validate,Secrets,Plan,Summary,RunnerPlan,Guard,Exact,FreshPlan check;
    class Review,Gate,DryRun,Decision,Backup decision;
    class Merge,Apply,Verify,RunnerApply action;
    class ReplaceApply danger;
    class Artifact,Stop,Revise artifact;
```

## Safety properties

1. Pull requests create plans but do not apply them.
2. Normal applies consume the encrypted, reviewed pull-request plan after merge rather than replanning `main`.
3. Runner deployment defaults to plan-only and refuses delete actions.
4. Replacement is explicitly destructive and requires a known restore path.
5. Every path ends with service-level verification, not merely a successful Terraform exit code.
