# Contributing

This is a personal production environment as well as a public reference project. Improvements are welcome, but changes need to preserve the repository's real topology and its safety controls.

## Good contributions

- fixes for inaccurate or unclear documentation
- Terraform validation, tests, and safer defaults
- narrowly scoped security or reliability improvements
- bug fixes that include a way to verify the behavior
- proposals that account for migration and recovery, not only the final state

Large topology changes and technology swaps are usually better discussed in an issue first. The lab is intentionally opinionated and maps to physical systems that are not fully represented in Git.

## Development workflow

1. Create a branch from `main`.
2. Keep the change focused on one problem.
3. Run the repository checks.
4. Open a pull request using the template.
5. Review every Terraform action produced by CI.
6. Merge only when the plan and operational impact are understood.

```bash
git checkout -b docs/clearer-runbook
pre-commit install
pre-commit run --all-files
```

## Terraform changes

Run formatting and validation in the affected deployment or module:

```bash
terraform fmt -recursive terraform/

cd terraform/deployments/<deployment>
terraform init
terraform validate
terraform plan -var-file=env/<environment>/terraform.tfvars
```

For modules with tests:

```bash
cd terraform/modules/compute/pm-cloudinit-vm
terraform init -backend=false
terraform test
```

Do not run a local apply as part of contribution testing. Deployment workflows plan pull requests and apply only after merge.

### Plan review

A pull request that changes infrastructure should explain:

- the target deployment and environment
- each create, update, delete, or replacement action
- expected downtime
- data and backup implications
- post-deployment verification
- rollback or recovery path

An unexplained replacement is a reason to stop, especially when cloud-init, disks, or a state move is involved.

### Modules

Deployments pin shared modules by Git ref. A module change should be backwards compatible by default, covered by tests, and released before consumers update their pin. Keep a module change and a fleet-wide adoption change separate when that makes the plans easier to reason about.

## Documentation changes

Documentation should describe the repository as it exists today.

- Mark future or historical work clearly.
- Prefer short examples from the real directory layout.
- Keep secrets, personal access details, and unverified network facts out of the docs.
- Update links and adjacent pages when renaming a concept.
- Use Mermaid for diagrams that benefit from living next to the text.
- Avoid filler sections and generic tutorials that do not help operate this lab.

## Commit and pull request style

Use a concise subject that says what changed:

```text
docs: clarify the VM replacement procedure
fix: preserve runner VMs when registration tokens rotate
feat: add a development frontend deployment
```

In the pull request body, focus on intent, evidence, risk, and verification. Screenshots are useful for visual changes; plan excerpts are useful when they do not expose sensitive values.

## Secrets and sensitive data

Never commit:

- API tokens, passwords, private keys, or runner registration tokens
- Terraform plans or local state
- `.env` files with live values
- internal logs containing rendered credentials
- backup contents or database exports

If a secret reaches a commit or CI log, rotate it immediately. Removing the line in a later commit is not sufficient.

## Review checklist

- [ ] The change is scoped and the reason is clear.
- [ ] Local checks pass.
- [ ] Documentation matches the implementation.
- [ ] The Terraform plan targets the intended workspace.
- [ ] Destructive actions are expected and recoverable.
- [ ] No sensitive value appears in the diff or output.
- [ ] A verification step is included.

For operating procedures, see the [runbook](docs/runbook.md). For the broader design, see the [architecture overview](docs/overview.md).
