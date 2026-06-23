# Week 2 Day 5 Release Checklist

## Image
- [ ] Dockerfile uses a specific base image tag.
- [ ] Build context excludes secrets and irrelevant files.
- [ ] Image has a local tag.
- [ ] Image can run from a clean container.

## Runtime
- [ ] Host port is documented.
- [ ] HTTP status is checked.
- [ ] Body marker is checked.
- [ ] Logs can be inspected.
- [ ] Cleanup is documented.

## Security
- [ ] No `.env` file is copied.
- [ ] No personal token, password, MFA code, SSH key, or cloud credential is present.
- [ ] Public push is not performed without explicit approval.

## Handoff
- [ ] README includes build, run, check, stop, cleanup.
- [ ] Failure note includes symptom, suspected cause, fix, recheck.
- [ ] Day 3 readiness note mentions Docker-to-MSA transition.
