# tools/

## computeplan.swift

Independent Swift capture tool used for the MLComputePlan placement evidence in this record. It compiles the shipped `.mlpackage` first via `MLModel.compileModel` (the v1 attempt, which loaded the uncompiled package directly, failed; both attempts are retained in `evidence/RUNLOG.md`), then builds an `MLComputePlan` for the compiled model, enumerates every operation including constants (5,267 per context), and prints, per operation, the preferred device reported by `MLComputePlan.deviceUsage(for:)` plus aggregate counts (`TOTAL`, `DEVICE ANE`, `DEVICE nil`, `NON_ANE` lines). Its raw output for each context is in `evidence/computeplan/c<context>.txt`.

Build (on the measurement device, macOS 27.3): `swiftc -O computeplan.swift -o computeplan` (see `evidence/setup.log` and `evidence/RUNLOG.md` for the exact session).

## computeplan.bin.sha256

SHA-256 of the compiled `computeplan` binary as run on the measurement device (85,656 bytes, built 2026-11-26): `4d6ca528dcdf804796964e7bdf4fb51be87e1a21aaf0ae5a9a62f103138de46a`. The binary itself is not republished; its source is `computeplan.swift` in this directory.
