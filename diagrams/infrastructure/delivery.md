# Infrastructure delivery flow

Most deployments use the reviewed path on the left. Platform stacks, runner provisioning, and deliberate replacement are exceptional paths that plan and apply in the same run.

```mermaid
flowchart TB
    Change["Focused change"] --> Local["Local formatting + checks"]
    Local --> PR["Pull request"]
    PR --> Detect["Detect changed deployment tiers"]
    Detect --> CI["Reusable Terraform CI"]
    CI --> Secrets["Resolve secret identifiers"]
    Secrets --> Validate["Init + validate"]
    Validate --> Plan["Create saved plan"]
    Plan --> Summary["Post plan summary"]
    Plan --> Artifact[("Encrypted plan artifact")]
    Summary --> Review{"Plan matches intent?"}

    Review -->|no| Revise["Revise configuration"]
    Revise --> Local
    Review -->|yes| Merge["Merge to main<br/>(required plans check)"]
    Merge --> Apply["Apply saved plan"]
    Artifact --> Apply
    Apply --> Verify["Verify Proxmox, guest,<br/>network, and service"]

    Platform["Push to main:<br/>shared or tfc"] --> Replan["Plan main"]
    Replan --> PlatformApply["Apply that plan"]
    PlatformApply --> Verify

    Manual["Manual runner dispatch"] --> RunnerPlan["Mint short-lived tokens<br/>and plan"]
    RunnerPlan --> Guard["Reject deletes, replacements,<br/>and duplicate registrations"]
    Guard --> DryRun{"dry_run enabled?"}
    DryRun -->|yes| Stop["No apply"]
    DryRun -->|no| RunnerApply["Apply runner plan"]
    RunnerApply --> Verify

    Replace["Manual replacement dispatch"] --> Backup{"Operator: backup and<br/>restore path confirmed?"}
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

    class Change,Manual,Replace,Platform input;
    class Local,PR,Detect,CI,Validate,Secrets,Plan,Summary,RunnerPlan,Guard,FreshPlan,Replan check;
    class Review,DryRun,Backup decision;
    class Merge,Apply,Verify,RunnerApply,PlatformApply action;
    class ReplaceApply danger;
    class Artifact,Stop,Revise artifact;
```

## Safety properties

1. Pull requests create plans but do not apply them.
2. A merge through `deploy.yaml` applies the encrypted pull-request plan rather than replanning `main`. The merge gate is the required `plans` check; no approval or environment reviewer is required.
3. `shared` and `tfc` replan on push to `main`, and a manual dispatch of `deploy.yaml` plans and applies in one run. These paths have no reviewed artifact.
4. Runner deployment defaults to plan-only and refuses deletes and replacements.
5. Replacement is explicitly destructive and auto-approved. Confirming a restore path is the operator's job; the workflow does not check it.
6. Every path ends with service-level verification, not merely a successful Terraform exit code.
