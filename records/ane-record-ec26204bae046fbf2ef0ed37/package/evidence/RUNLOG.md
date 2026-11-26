# RUNLOG — N3 replication v0.6.0
- 2026-11-26 15:00:44 EST — phase1 started on Naytes-MacBook-Neo.local 27.3 26C5047e
15:00  up  8:24, 1 user, load averages: 16.56 21.67 34.43
Filesystem      Size    Used   Avail Capacity iused ifree %iused  Mounted on
/dev/disk3s1   460Gi   363Gi    62Gi    86%    3.4M  652M    1%   /System/Volumes/Data
- 2026-11-26 15:00:44 EST — runner tar contents:
/Users/nayte/ane-records-v060-scratch/work/runner-extract
/Users/nayte/ane-records-v060-scratch/work/runner-extract/lfm3-ane-runner-r5
/Users/nayte/ane-records-v060-scratch/work/runner-extract/lfm3-ane-runner-r5/setup.sh
/Users/nayte/ane-records-v060-scratch/work/runner-extract/lfm3-ane-runner-r5/anec-run
/Users/nayte/ane-records-v060-scratch/work/runner-extract/lfm3-ane-runner-r5/model
/Users/nayte/ane-records-v060-scratch/work/runner-extract/lfm3-ane-runner-r5/model/config.json
/Users/nayte/ane-records-v060-scratch/work/runner-extract/lfm3-ane-runner-r5/embed.safetensors.header
- 2026-11-26 15:00:44 EST — cloning tokenizer repo shallow
- 2026-11-26 15:00:46 EST — tokenizer copied from clone
total 34984
-rw-r--r--@ 1 nayte  staff    17M Nov 26 15:00 tokenizer.json
- 2026-11-26 15:00:46 EST — phase1 setup part done
- 2026-11-26 15:01:29 EST — phase2 main started
- 2026-11-26 15:01:29 EST — runner at /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5 exists=True
- 2026-11-26 15:01:30 EST — setup.sh rc=0 out=ready: /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model err=
- 2026-11-26 15:01:30 EST — anec-run --help captured, first line: usage: anec-run <compiled-dir> --model <dir> [--tokens a,b,c | --prompt text --tokenizer tokenizer.json [--raw 1] [--system s] [--think 1] [--think-tag 0|1] [--chat 1] | --serve port | --seed S] [--int-mod M] [--generate N | --max-tokens N] [--temperature T] [--top-k K] [--repetition-penalty R] [--min-seconds T] [--packed-embed path] [--prefill <compiled-dir>] [--grow <dir1,dir2>] [--spec-k K] [--spec-draft auto|ngram|suffix-only|table-only|model|ngram+model|jacobi|none] [--ngram-table <table.bin>] [--draft-model <s1-compiled-dir>] [--draft-model-src <dir>] [--draft-packed-embed <path>] [--draft-steps D] [--fallback-s1 <s1-compiled-dir>] [--dflash <compile-dflash-dir>] [--units ane|gpu|cpu|all] [--carry generic] [--stats 1] [--iters N] [--max-requests N] [--model-id id] [--dump dir] [--dump-cuts dir] [--out json]
- 2026-11-26 15:01:30 EST — asset hash SHA256SUMS c72825c8336718538adc0f7017b2414d6c7eea5edb46938b38e6b8e05ab13e1a
- 2026-11-26 15:01:31 EST — asset hash embed_tokens.bf16.bin 5f1df3bbc564554f48a7fb542f96e745c92e2315c92279944d9e65d234bec4bc
- 2026-11-26 15:01:31 EST — asset hash lfm3-1.7b-pruned7168-strict-lut4-c1024.tar 91d4bcb0a2234dd4a87880d730186b047b730da31973e5ec3bf451f220ef07ed
- 2026-11-26 15:01:32 EST — asset hash lfm3-1.7b-pruned7168-strict-lut4-c2048.tar 9f869ebba7961e056813e54eeb80ef7af5ed6ce39cd93f250a6488615e235c2f
- 2026-11-26 15:01:32 EST — asset hash lfm3-1.7b-pruned7168-strict-lut4-c256.tar a9b3f866ee589bdeb02e1b25ea283dfabfcad93a01907e912caf9e3949cf366a
- 2026-11-26 15:01:33 EST — asset hash lfm3-1.7b-pruned7168-strict-lut4-c4096.tar b151274754fed55a163a3ca7151e9a2b07b6811297ab56bcf37057417b4f0505
- 2026-11-26 15:01:34 EST — asset hash lfm3-1.7b-pruned7168-strict-lut4-c512.tar e66da789940deb8933bfc90b7407377d9c18db30244e89aa8b763a920d22fbde
- 2026-11-26 15:01:34 EST — asset hash lfm3-ane-runner-r5-macos-arm64.tar 0279b0ae76e87992fb66dcda6ac2e4c7063e6d8f572b99717aceb2e04d536da6
- 2026-11-26 15:01:34 EST — ane-re checkout MISSING at /Users/nayte/.local/share/anvil/v050/ane-re — using fresh profile-repo per task fallback
- 2026-11-26 15:01:34 EST — profile commit rc=0 [main (root-commit) 2dc9d12] Freeze LFM3 v0.6.0 replication profile before counted runs
 1 file changed, 33 insertions(+)
 create mode 100644 lfm3-v060-strict-lut4-20261126.json 
- 2026-11-26 15:01:34 EST — profile committed_where=/Users/nayte/ane-records-v060-scratch/work/profile-repo/lfm3-v060-strict-lut4-20261126.json commit=2dc9d12146ba10607683424c4b99476229e70fd9 profileHash=2f8a1f3837bc9df4af899b507afbfff0756318d4ef9df52014a7482e9df0c624
- 2026-11-26 15:01:35 EST — c256 plan.json: {"carried": [{"input": "L0_conv_win", "output": "L0_bx", "state": "L0_conv_win", "type": {"dtype": "fp16", "shape": [6, 2048]}, "update": {"nodes": [{"inputs": [], "name": "L0_conv_win", "op": {"input": {"name": "L0_conv_win"}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}, {"inputs": [], "name": "L0_bx", "op": {"input": {"name": "L0_bx"}}, "type": {"dtype": "fp16", "shape": [1, 2048]}}, {"inputs": [0, 1], "name": "L0_conv_win_ext", "op": {"concat": {"axis": 0}}, "type": {"dtype": "fp16", "shape": [7, 2048]}}, {"inputs": [2], "name": "L0_conv_win_next", "op": {"slice": {"begin": [1, 0], "end": [7, 2048], "stride": [1, 1]}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}], "outputs": [3]}}, {"input": "L1_conv_win", "output": "L1_bx", "state": "L1_conv_win", "type": {"dtype": "fp16", "shap
- 2026-11-26 15:01:35 EST — c256 certificate.json excerpt: {
  "compilerVersion" : "0.2.0",
  "configSHA256" : "4804e0d97e2727fdc25fb4a1e9a08292dfb04d95abb097e89a7a5b64babed999",
  "declaredEffects" : [
    "weights: source tensors converted to IEEE binary16 (round-to-nearest-even); inexact element counts per tensor recorded",
    "constants: inline float constants and epsilons rounded to binary16 (recorded per node in rewrites)",
    "mask: causal mask uses -10000.0 in place of -infinity",
    "weights: 143 tensors palettized (LUT4, profile cand1_g4conv_w2_g8); the program certified here IS the palettized one, and each tensor's error against the fp16
- 2026-11-26 15:01:35 EST — c256 semantic.json excerpt: {"nodes":[{"inputs":[],"name":"rope_cos","op":{"input":{"name":"rope_cos"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin","op":{"input":{"name":"rope_sin"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask","op":{"input":{"name":"attn_mask"}},"type":{"dtype":"fp16","shape":[1,256]}},{"inputs":[],"name":"rope_cos_sw","op":{"input":{"name":"rope_cos_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin_sw","op":{"input":{"name":"rope_sin_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask_sw","op":{
- 2026-11-26 15:01:38 EST — c256 weight.bin sha256=5351b1f460826bdffbedf6cd135deb05276d93b03f9be7d56157c0a76217a183 size=831054208 match=True
- 2026-11-26 15:01:38 EST — c512 plan.json: {"carried": [{"input": "L0_conv_win", "output": "L0_bx", "state": "L0_conv_win", "type": {"dtype": "fp16", "shape": [6, 2048]}, "update": {"nodes": [{"inputs": [], "name": "L0_conv_win", "op": {"input": {"name": "L0_conv_win"}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}, {"inputs": [], "name": "L0_bx", "op": {"input": {"name": "L0_bx"}}, "type": {"dtype": "fp16", "shape": [1, 2048]}}, {"inputs": [0, 1], "name": "L0_conv_win_ext", "op": {"concat": {"axis": 0}}, "type": {"dtype": "fp16", "shape": [7, 2048]}}, {"inputs": [2], "name": "L0_conv_win_next", "op": {"slice": {"begin": [1, 0], "end": [7, 2048], "stride": [1, 1]}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}], "outputs": [3]}}, {"input": "L1_conv_win", "output": "L1_bx", "state": "L1_conv_win", "type": {"dtype": "fp16", "shap
- 2026-11-26 15:01:38 EST — c512 certificate.json excerpt: {
  "compilerVersion" : "0.2.0",
  "configSHA256" : "4804e0d97e2727fdc25fb4a1e9a08292dfb04d95abb097e89a7a5b64babed999",
  "declaredEffects" : [
    "weights: source tensors converted to IEEE binary16 (round-to-nearest-even); inexact element counts per tensor recorded",
    "constants: inline float constants and epsilons rounded to binary16 (recorded per node in rewrites)",
    "mask: causal mask uses -10000.0 in place of -infinity",
    "weights: 143 tensors palettized (LUT4, profile cand1_g4conv_w2_g8); the program certified here IS the palettized one, and each tensor's error against the fp16
- 2026-11-26 15:01:38 EST — c512 semantic.json excerpt: {"nodes":[{"inputs":[],"name":"rope_cos","op":{"input":{"name":"rope_cos"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin","op":{"input":{"name":"rope_sin"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask","op":{"input":{"name":"attn_mask"}},"type":{"dtype":"fp16","shape":[1,512]}},{"inputs":[],"name":"rope_cos_sw","op":{"input":{"name":"rope_cos_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin_sw","op":{"input":{"name":"rope_sin_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask_sw","op":{
- 2026-11-26 15:01:41 EST — c512 weight.bin sha256=5351b1f460826bdffbedf6cd135deb05276d93b03f9be7d56157c0a76217a183 size=831054208 match=True
- 2026-11-26 15:01:41 EST — c1024 plan.json: {"carried": [{"input": "L0_conv_win", "output": "L0_bx", "state": "L0_conv_win", "type": {"dtype": "fp16", "shape": [6, 2048]}, "update": {"nodes": [{"inputs": [], "name": "L0_conv_win", "op": {"input": {"name": "L0_conv_win"}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}, {"inputs": [], "name": "L0_bx", "op": {"input": {"name": "L0_bx"}}, "type": {"dtype": "fp16", "shape": [1, 2048]}}, {"inputs": [0, 1], "name": "L0_conv_win_ext", "op": {"concat": {"axis": 0}}, "type": {"dtype": "fp16", "shape": [7, 2048]}}, {"inputs": [2], "name": "L0_conv_win_next", "op": {"slice": {"begin": [1, 0], "end": [7, 2048], "stride": [1, 1]}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}], "outputs": [3]}}, {"input": "L1_conv_win", "output": "L1_bx", "state": "L1_conv_win", "type": {"dtype": "fp16", "shap
- 2026-11-26 15:01:41 EST — c1024 certificate.json excerpt: {
  "compilerVersion" : "0.2.0",
  "configSHA256" : "4804e0d97e2727fdc25fb4a1e9a08292dfb04d95abb097e89a7a5b64babed999",
  "declaredEffects" : [
    "weights: source tensors converted to IEEE binary16 (round-to-nearest-even); inexact element counts per tensor recorded",
    "constants: inline float constants and epsilons rounded to binary16 (recorded per node in rewrites)",
    "mask: causal mask uses -10000.0 in place of -infinity",
    "weights: 143 tensors palettized (LUT4, profile cand1_g4conv_w2_g8); the program certified here IS the palettized one, and each tensor's error against the fp16
- 2026-11-26 15:01:41 EST — c1024 semantic.json excerpt: {"nodes":[{"inputs":[],"name":"rope_cos","op":{"input":{"name":"rope_cos"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin","op":{"input":{"name":"rope_sin"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask","op":{"input":{"name":"attn_mask"}},"type":{"dtype":"fp16","shape":[1,1024]}},{"inputs":[],"name":"rope_cos_sw","op":{"input":{"name":"rope_cos_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin_sw","op":{"input":{"name":"rope_sin_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask_sw","op":
- 2026-11-26 15:01:44 EST — c1024 weight.bin sha256=5351b1f460826bdffbedf6cd135deb05276d93b03f9be7d56157c0a76217a183 size=831054208 match=True
- 2026-11-26 15:01:44 EST — c2048 plan.json: {"carried": [{"input": "L0_conv_win", "output": "L0_bx", "state": "L0_conv_win", "type": {"dtype": "fp16", "shape": [6, 2048]}, "update": {"nodes": [{"inputs": [], "name": "L0_conv_win", "op": {"input": {"name": "L0_conv_win"}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}, {"inputs": [], "name": "L0_bx", "op": {"input": {"name": "L0_bx"}}, "type": {"dtype": "fp16", "shape": [1, 2048]}}, {"inputs": [0, 1], "name": "L0_conv_win_ext", "op": {"concat": {"axis": 0}}, "type": {"dtype": "fp16", "shape": [7, 2048]}}, {"inputs": [2], "name": "L0_conv_win_next", "op": {"slice": {"begin": [1, 0], "end": [7, 2048], "stride": [1, 1]}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}], "outputs": [3]}}, {"input": "L1_conv_win", "output": "L1_bx", "state": "L1_conv_win", "type": {"dtype": "fp16", "shap
- 2026-11-26 15:01:44 EST — c2048 certificate.json excerpt: {
  "compilerVersion" : "0.2.0",
  "configSHA256" : "4804e0d97e2727fdc25fb4a1e9a08292dfb04d95abb097e89a7a5b64babed999",
  "declaredEffects" : [
    "weights: source tensors converted to IEEE binary16 (round-to-nearest-even); inexact element counts per tensor recorded",
    "constants: inline float constants and epsilons rounded to binary16 (recorded per node in rewrites)",
    "mask: causal mask uses -10000.0 in place of -infinity",
    "weights: 143 tensors palettized (LUT4, profile cand1_g4conv_w2_g8); the program certified here IS the palettized one, and each tensor's error against the fp16
- 2026-11-26 15:01:44 EST — c2048 semantic.json excerpt: {"nodes":[{"inputs":[],"name":"rope_cos","op":{"input":{"name":"rope_cos"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin","op":{"input":{"name":"rope_sin"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask","op":{"input":{"name":"attn_mask"}},"type":{"dtype":"fp16","shape":[1,2048]}},{"inputs":[],"name":"rope_cos_sw","op":{"input":{"name":"rope_cos_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin_sw","op":{"input":{"name":"rope_sin_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask_sw","op":
- 2026-11-26 15:01:48 EST — c2048 weight.bin sha256=5351b1f460826bdffbedf6cd135deb05276d93b03f9be7d56157c0a76217a183 size=831054208 match=True
- 2026-11-26 15:01:48 EST — c4096 plan.json: {"carried": [{"input": "L0_conv_win", "output": "L0_bx", "state": "L0_conv_win", "type": {"dtype": "fp16", "shape": [6, 2048]}, "update": {"nodes": [{"inputs": [], "name": "L0_conv_win", "op": {"input": {"name": "L0_conv_win"}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}, {"inputs": [], "name": "L0_bx", "op": {"input": {"name": "L0_bx"}}, "type": {"dtype": "fp16", "shape": [1, 2048]}}, {"inputs": [0, 1], "name": "L0_conv_win_ext", "op": {"concat": {"axis": 0}}, "type": {"dtype": "fp16", "shape": [7, 2048]}}, {"inputs": [2], "name": "L0_conv_win_next", "op": {"slice": {"begin": [1, 0], "end": [7, 2048], "stride": [1, 1]}}, "type": {"dtype": "fp16", "shape": [6, 2048]}}], "outputs": [3]}}, {"input": "L1_conv_win", "output": "L1_bx", "state": "L1_conv_win", "type": {"dtype": "fp16", "shap
- 2026-11-26 15:01:48 EST — c4096 certificate.json excerpt: {
  "compilerVersion" : "0.2.0",
  "configSHA256" : "4804e0d97e2727fdc25fb4a1e9a08292dfb04d95abb097e89a7a5b64babed999",
  "declaredEffects" : [
    "weights: source tensors converted to IEEE binary16 (round-to-nearest-even); inexact element counts per tensor recorded",
    "constants: inline float constants and epsilons rounded to binary16 (recorded per node in rewrites)",
    "mask: causal mask uses -10000.0 in place of -infinity",
    "weights: 143 tensors palettized (LUT4, profile cand1_g4conv_w2_g8); the program certified here IS the palettized one, and each tensor's error against the fp16
- 2026-11-26 15:01:48 EST — c4096 semantic.json excerpt: {"nodes":[{"inputs":[],"name":"rope_cos","op":{"input":{"name":"rope_cos"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin","op":{"input":{"name":"rope_sin"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask","op":{"input":{"name":"attn_mask"}},"type":{"dtype":"fp16","shape":[1,4096]}},{"inputs":[],"name":"rope_cos_sw","op":{"input":{"name":"rope_cos_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"rope_sin_sw","op":{"input":{"name":"rope_sin_sw"}},"type":{"dtype":"fp16","shape":[1,128]}},{"inputs":[],"name":"attn_mask_sw","op":
- 2026-11-26 15:01:52 EST — c4096 weight.bin sha256=5351b1f460826bdffbedf6cd135deb05276d93b03f9be7d56157c0a76217a183 size=831054208 match=True
- 2026-11-26 15:01:52 EST — building computeplan swift tool
- 2026-11-26 15:01:58 EST — computeplan build rc=1 err=/Users/nayte/ane-records-v060-scratch/work/tools/computeplan.swift:23:48: error: value of type 'MLModelStructure' has no member 'functions'
21 |             }
22 |         }
23 |         for (fname, fn) in plan.modelStructure.functions {
   |                                                `- error: value of type 'MLModelStructure' has no member 'functions'
24 |             for op in fn.operations {
25 |                 total += 1

- 2026-11-26 15:01:58 EST — computeplan build FAILED — fallback to plan.json only, disclosed
- 2026-11-26 15:01:58 EST — phase2 placement+weights+computeplan done
- 2026-11-26 15:02:55 EST — profile correction: initial profile included SHA256SUMS helper file as an 8th entry; correcting to exactly the 7 release assets BEFORE any counted run
- 2026-11-26 15:03:01 EST — corrected profile commit=40b220df5db3318cc65f86a04ec516f9ea2729ed profileHash=6d740b62fccb723617eeabde3eb917fc6a95e461078f3e978e30b1dba1548f1c rc=0
- 2026-11-26 15:03:01 EST — load gate polling start (up to ~25 min, 60s interval)
- 2026-11-26 15:03:01 EST — load poll 1min=13.0 raw=15:03  up  8:27, 1 user, load averages: 13.00 18.35 31.16
- 2026-11-26 15:04:00 EST — computeplan c256 start pkg_exists=True
- 2026-11-26 15:04:00 EST — computeplan c256 rc=-6 out=libc++abi: terminating due to uncaught exception of type std::__1::ios_base::failure: Failed to open file: /Users/nayte/ane-records-v060-scratch/work/tmp-cp-256/lfm3_cand1_lut4_C256/seg01_dev.mlpackage/coremldata.bin. It is not a valid .mlmodelc file. : unspecified iostream_category error

- 2026-11-26 15:04:02 EST — load poll 1min=13.93 raw=15:04  up  8:28, 1 user, load averages: 13.93 17.91 30.13
- 2026-11-26 15:04:04 EST — computeplan c512 start pkg_exists=True
- 2026-11-26 15:04:04 EST — computeplan c512 rc=-6 out=libc++abi: terminating due to uncaught exception of type std::__1::ios_base::failure: Failed to open file: /Users/nayte/ane-records-v060-scratch/work/tmp-cp-512/lfm3_cand1_lut4_C512/seg01_dev.mlpackage/coremldata.bin. It is not a valid .mlmodelc file. : unspecified iostream_category error

- 2026-11-26 15:04:09 EST — computeplan c1024 start pkg_exists=True
- 2026-11-26 15:04:09 EST — computeplan c1024 rc=-6 out=libc++abi: terminating due to uncaught exception of type std::__1::ios_base::failure: Failed to open file: /Users/nayte/ane-records-v060-scratch/work/tmp-cp-1024/lfm3_cand1_lut4_C1024/seg01_dev.mlpackage/coremldata.bin. It is not a valid .mlmodelc file. : unspecified iostream_category error

- 2026-11-26 15:04:14 EST — computeplan c2048 start pkg_exists=True
- 2026-11-26 15:04:14 EST — computeplan c2048 rc=-6 out=libc++abi: terminating due to uncaught exception of type std::__1::ios_base::failure: Failed to open file: /Users/nayte/ane-records-v060-scratch/work/tmp-cp-2048/lfm3_cand1_lut4_C2048/seg01_dev.mlpackage/coremldata.bin. It is not a valid .mlmodelc file. : unspecified iostream_category error

- 2026-11-26 15:04:19 EST — computeplan c4096 start pkg_exists=True
- 2026-11-26 15:04:19 EST — computeplan c4096 rc=-6 out=libc++abi: terminating due to uncaught exception of type std::__1::ios_base::failure: Failed to open file: /Users/nayte/ane-records-v060-scratch/work/tmp-cp-4096/lfm3_cand1_lut4_C4096/seg01_dev.mlpackage/coremldata.bin. It is not a valid .mlmodelc file. : unspecified iostream_category error

- 2026-11-26 15:04:19 EST — computeplan all contexts done
- Thu Nov 26 15:04:25 EST 2026 — computeplan v2 (compileModel first) rerun, v1 failures above retained
- 2026-11-26 15:04:30 EST — computeplan c256 start pkg_exists=True
- 2026-11-26 15:05:02 EST — load poll 1min=11.21 raw=15:05  up  8:29, 1 user, load averages: 11.21 16.19 28.64
- 2026-11-26 15:06:02 EST — load poll 1min=43.96 raw=15:06  up  8:30, 1 user, load averages: 43.96 26.12 31.59
- 2026-11-26 15:06:29 EST — computeplan c256 rc=0 out=COMPILING mlpackage first via MLModel.compileModel
COMPILED_TO /var/folders/lz/s7y5jp495qb15dx25bwplj680000gn/T/seg01_dev.mlmodelc
TOTAL 5267
DEVICE ANE 1756
DEVICE nil 3511
NON_ANE_COUNT 3511
NON_ANE main: const outputs=L0_norm1_unit_m1 pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_axis pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_interleave pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_axes pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_eps pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_begin pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_end pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_stride pref=nil
NON_ANE main: const outpu
- 2026-11-26 15:06:34 EST — computeplan c512 start pkg_exists=True
- 2026-11-26 15:07:03 EST — load poll 1min=27.69 raw=15:07  up  8:31, 1 user, load averages: 27.69 24.43 30.57
- 2026-11-26 15:08:03 EST — load poll 1min=18.24 raw=15:08  up  8:32, 1 user, load averages: 18.24 22.42 29.41
- 2026-11-26 15:08:35 EST — computeplan c512 rc=0 out=COMPILING mlpackage first via MLModel.compileModel
COMPILED_TO /var/folders/lz/s7y5jp495qb15dx25bwplj680000gn/T/seg01_dev_DF848B52-32BB-4A55-9B79-6A89D8BF9679.mlmodelc
TOTAL 5267
DEVICE ANE 1756
DEVICE nil 3511
NON_ANE_COUNT 3511
NON_ANE main: const outputs=L0_norm1_unit_m1 pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_axis pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_interleave pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_axes pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_eps pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_begin pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_end pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_stri
- 2026-11-26 15:08:40 EST — computeplan c1024 start pkg_exists=True
- 2026-11-26 15:09:04 EST — load poll 1min=15.98 raw=15:09  up  8:33, 1 user, load averages: 15.98 20.80 28.31
- 2026-11-26 15:10:04 EST — load poll 1min=11.3 raw=15:10  up  8:34, 1 user, load averages: 11.30 18.51 26.94
- 2026-11-26 15:10:23 EST — computeplan c1024 rc=0 out=COMPILING mlpackage first via MLModel.compileModel
COMPILED_TO /var/folders/lz/s7y5jp495qb15dx25bwplj680000gn/T/seg01_dev_5BBAB3B2-776F-469F-88BC-55992148F36F.mlmodelc
TOTAL 5267
DEVICE ANE 1756
DEVICE nil 3511
NON_ANE_COUNT 3511
NON_ANE main: const outputs=L0_norm1_unit_m1 pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_axis pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_interleave pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_axes pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_eps pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_begin pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_end pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_stri
- 2026-11-26 15:10:30 EST — computeplan c2048 start pkg_exists=True
- 2026-11-26 15:11:04 EST — load poll 1min=14.5 raw=15:11  up  8:35, 1 user, load averages: 14.50 18.22 26.26
- 2026-11-26 15:12:04 EST — load poll 1min=25.11 raw=15:12  up  8:36, 1 user, load averages: 25.11 21.32 26.91
- 2026-11-26 15:12:31 EST — computeplan c2048 rc=0 out=COMPILING mlpackage first via MLModel.compileModel
COMPILED_TO /var/folders/lz/s7y5jp495qb15dx25bwplj680000gn/T/seg01_dev_5E9A9275-8820-4DF6-B812-E52849ED825E.mlmodelc
TOTAL 5267
DEVICE ANE 1756
DEVICE nil 3511
NON_ANE_COUNT 3511
NON_ANE main: const outputs=L0_norm1_unit_m1 pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_axis pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_interleave pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_axes pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_eps pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_begin pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_end pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_stri
- 2026-11-26 15:12:37 EST — computeplan c4096 start pkg_exists=True
- 2026-11-26 15:13:05 EST — load poll 1min=17.53 raw=15:13  up  8:37, 1 user, load averages: 17.53 20.29 26.14
- 2026-11-26 15:14:05 EST — load poll 1min=19.3 raw=15:14  up  8:38, 1 user, load averages: 19.30 19.91 25.57
- 2026-11-26 15:14:40 EST — computeplan c4096 rc=0 out=COMPILING mlpackage first via MLModel.compileModel
COMPILED_TO /var/folders/lz/s7y5jp495qb15dx25bwplj680000gn/T/seg01_dev_A2FBCE10-BCA9-42D7-B8F0-E1F7FFA29188.mlmodelc
TOTAL 5267
DEVICE ANE 1756
DEVICE nil 3511
NON_ANE_COUNT 3511
NON_ANE main: const outputs=L0_norm1_unit_m1 pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_axis pref=nil
NON_ANE main: const outputs=L0_norm1_unit_cat_interleave pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_axes pref=nil
NON_ANE main: const outputs=L0_norm1_unit_ln_eps pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_begin pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_end pref=nil
NON_ANE main: const outputs=L0_norm1_unit_half_stri
- 2026-11-26 15:14:40 EST — computeplan all contexts done
- 2026-11-26 15:15:05 EST — load poll 1min=22.59 raw=15:15  up  8:39, 1 user, load averages: 22.59 21.22 25.71
- 2026-11-26 15:16:06 EST — load poll 1min=19.44 raw=15:16  up  8:40, 1 user, load averages: 19.44 20.60 25.17
- 2026-11-26 15:17:06 EST — load poll 1min=27.67 raw=15:17  up  8:41, 1 user, load averages: 27.67 22.90 25.73
- 2026-11-26 15:18:06 EST — load poll 1min=14.65 raw=15:18  up  8:42, 1 user, load averages: 14.65 20.13 24.51
- 2026-11-26 15:19:06 EST — load poll 1min=14.53 raw=15:19  up  8:43, 1 user, load averages: 14.53 18.84 23.71
- 2026-11-26 15:20:06 EST — load poll 1min=9.86 raw=15:20  up  8:44, 1 user, load averages: 9.86 17.00 22.71
- 2026-11-26 15:21:06 EST — load poll 1min=6.18 raw=15:21  up  8:45, 1 user, load averages: 6.18 14.68 21.45
- 2026-11-26 15:22:07 EST — load poll 1min=8.07 raw=15:22  up  8:46, 1 user, load averages: 8.07 13.87 20.70
- 2026-11-26 15:23:07 EST — load poll 1min=6.76 raw=15:23  up  8:47, 1 user, load averages: 6.76 12.38 19.67
- 2026-11-26 15:24:07 EST — load poll 1min=9.73 raw=15:24  up  8:48, 1 user, load averages: 9.73 12.38 19.18
- 2026-11-26 15:25:07 EST — load poll 1min=8.09 raw=15:25  up  8:49, 1 user, load averages: 8.09 11.28 18.30
- 2026-11-26 15:26:08 EST — load poll 1min=8.23 raw=15:26  up  8:50, 1 user, load averages: 8.23 10.90 17.68
- 2026-11-26 15:27:08 EST — load poll 1min=5.68 raw=15:27  up  8:51, 1 user, load averages: 5.68 9.69 16.77
- 2026-11-26 15:28:08 EST — load gate result guarded_window=False minload_seen_in_this_poll=5.68
- 2026-11-26 15:28:08 EST — before c256 runs load=6.84 15:28  up  8:52, 1 user, load averages: 6.84 9.28 16.13
- 2026-11-26 15:28:10 EST — c256 extracted pkgdir exists=True listing=['lfm3_cand1_lut4_C256']
- 2026-11-26 15:28:10 EST — c256 run-1 START load=6.54 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-256/lfm3_cand1_lut4_C256 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:28:40 EST — c256 run-1 END rc=0 wall=30.727s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 569 ms | 16 new tokens | 40.0 tok/s | position 33 of 256]\n> '
- 2026-11-26 15:28:40 EST — c256 run-2 START load=5.31 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-256/lfm3_cand1_lut4_C256 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:28:42 EST — c256 run-2 END rc=0 wall=1.458s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 513 ms | 16 new tokens | 41.2 tok/s | position 33 of 256]\n> '
- 2026-11-26 15:28:42 EST — c256 run-3 START load=5.31 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-256/lfm3_cand1_lut4_C256 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:28:43 EST — c256 run-3 END rc=0 wall=1.428s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 538 ms | 16 new tokens | 34.8 tok/s | position 33 of 256]\n> '
- 2026-11-26 15:28:43 EST — c256 run-4 START load=5.31 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-256/lfm3_cand1_lut4_C256 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:28:45 EST — c256 run-4 END rc=0 wall=1.407s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 523 ms | 16 new tokens | 38.2 tok/s | position 33 of 256]\n> '
- 2026-11-26 15:28:45 EST — c256 run-5 START load=5.21 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-256/lfm3_cand1_lut4_C256 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:28:46 EST — c256 run-5 END rc=0 wall=1.365s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 525 ms | 16 new tokens | 39.9 tok/s | position 33 of 256]\n> '
- 2026-11-26 15:28:46 EST — c256 DONE identical=True hashes=['f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2']
- 2026-11-26 15:28:46 EST — c256 extract deleted
- 2026-11-26 15:28:46 EST — before c512 runs load=5.21 15:28  up  8:52, 1 user, load averages: 5.21 8.54 15.54
- 2026-11-26 15:28:48 EST — c512 extracted pkgdir exists=True listing=['lfm3_cand1_lut4_C512']
- 2026-11-26 15:28:48 EST — c512 run-1 START load=5.21 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-512/lfm3_cand1_lut4_C512 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:29:20 EST — c512 run-1 END rc=0 wall=32.190s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 652 ms | 16 new tokens | 38.2 tok/s | position 33 of 512]\n> '
- 2026-11-26 15:29:20 EST — c512 run-2 START load=4.29 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-512/lfm3_cand1_lut4_C512 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:29:21 EST — c512 run-2 END rc=0 wall=1.645s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 610 ms | 16 new tokens | 38.6 tok/s | position 33 of 512]\n> '
- 2026-11-26 15:29:22 EST — c512 run-3 START load=4.29 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-512/lfm3_cand1_lut4_C512 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:29:23 EST — c512 run-3 END rc=0 wall=1.455s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 598 ms | 16 new tokens | 38.8 tok/s | position 33 of 512]\n> '
- 2026-11-26 15:29:23 EST — c512 run-4 START load=4.29 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-512/lfm3_cand1_lut4_C512 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:29:24 EST — c512 run-4 END rc=0 wall=1.530s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 606 ms | 16 new tokens | 33.1 tok/s | position 33 of 512]\n> '
- 2026-11-26 15:29:25 EST — c512 run-5 START load=4.29 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-512/lfm3_cand1_lut4_C512 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:29:26 EST — c512 run-5 END rc=0 wall=1.439s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 596 ms | 16 new tokens | 38.9 tok/s | position 33 of 512]\n> '
- 2026-11-26 15:29:26 EST — c512 DONE identical=True hashes=['f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2']
- 2026-11-26 15:29:26 EST — c512 extract deleted
- 2026-11-26 15:29:26 EST — before c1024 runs load=4.27 15:29  up  8:53, 1 user, load averages: 4.27 7.88 14.98
- 2026-11-26 15:29:28 EST — c1024 extracted pkgdir exists=True listing=['lfm3_cand1_lut4_C1024']
- 2026-11-26 15:29:28 EST — c1024 run-1 START load=4.27 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-1024/lfm3_cand1_lut4_C1024 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:04 EST — c1024 run-1 END rc=0 wall=35.778s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 806 ms | 16 new tokens | 34.5 tok/s | position 33 of 1024]\n> '
- 2026-11-26 15:30:04 EST — c1024 run-2 START load=8.86 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-1024/lfm3_cand1_lut4_C1024 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:05 EST — c1024 run-2 END rc=0 wall=1.796s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 748 ms | 16 new tokens | 31.7 tok/s | position 33 of 1024]\n> '
- 2026-11-26 15:30:05 EST — c1024 run-3 START load=8.47 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-1024/lfm3_cand1_lut4_C1024 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:07 EST — c1024 run-3 END rc=0 wall=1.646s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 755 ms | 16 new tokens | 35.4 tok/s | position 33 of 1024]\n> '
- 2026-11-26 15:30:07 EST — c1024 run-4 START load=8.47 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-1024/lfm3_cand1_lut4_C1024 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:09 EST — c1024 run-4 END rc=0 wall=1.710s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 810 ms | 16 new tokens | 35.3 tok/s | position 33 of 1024]\n> '
- 2026-11-26 15:30:09 EST — c1024 run-5 START load=8.47 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-1024/lfm3_cand1_lut4_C1024 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:10 EST — c1024 run-5 END rc=0 wall=1.638s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 757 ms | 16 new tokens | 35.9 tok/s | position 33 of 1024]\n> '
- 2026-11-26 15:30:10 EST — c1024 DONE identical=True hashes=['f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2']
- 2026-11-26 15:30:11 EST — c1024 extract deleted
- 2026-11-26 15:30:11 EST — before c2048 runs load=8.11 15:30  up  8:54, 1 user, load averages: 8.11 8.44 14.82
- 2026-11-26 15:30:12 EST — c2048 extracted pkgdir exists=True listing=['lfm3_cand1_lut4_C2048']
- 2026-11-26 15:30:12 EST — c2048 run-1 START load=8.11 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-2048/lfm3_cand1_lut4_C2048 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:51 EST — c2048 run-1 END rc=0 wall=38.629s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1154 ms | 16 new tokens | 30.7 tok/s | position 33 of 2048]\n> '
- 2026-11-26 15:30:51 EST — c2048 run-2 START load=10.28 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-2048/lfm3_cand1_lut4_C2048 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:53 EST — c2048 run-2 END rc=0 wall=2.177s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1108 ms | 16 new tokens | 30.2 tok/s | position 33 of 2048]\n> '
- 2026-11-26 15:30:53 EST — c2048 run-3 START load=10.28 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-2048/lfm3_cand1_lut4_C2048 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:55 EST — c2048 run-3 END rc=0 wall=2.001s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1053 ms | 16 new tokens | 30.6 tok/s | position 33 of 2048]\n> '
- 2026-11-26 15:30:55 EST — c2048 run-4 START load=9.85 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-2048/lfm3_cand1_lut4_C2048 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:57 EST — c2048 run-4 END rc=0 wall=1.895s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 987 ms | 16 new tokens | 33.3 tok/s | position 33 of 2048]\n> '
- 2026-11-26 15:30:57 EST — c2048 run-5 START load=9.85 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-2048/lfm3_cand1_lut4_C2048 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:30:59 EST — c2048 run-5 END rc=0 wall=2.092s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1094 ms | 16 new tokens | 30.5 tok/s | position 33 of 2048]\n> '
- 2026-11-26 15:30:59 EST — c2048 DONE identical=True hashes=['f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2']
- 2026-11-26 15:30:59 EST — c2048 extract deleted
- 2026-11-26 15:30:59 EST — before c4096 runs load=9.85 15:30  up  8:55, 1 user, load averages: 9.85 8.81 14.62
- 2026-11-26 15:31:01 EST — c4096 extracted pkgdir exists=True listing=['lfm3_cand1_lut4_C4096']
- 2026-11-26 15:31:01 EST — c4096 run-1 START load=9.22 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-4096/lfm3_cand1_lut4_C4096 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:31:40 EST — c4096 run-1 END rc=0 wall=39.357s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1736 ms | 16 new tokens | 24.3 tok/s | position 33 of 4096]\n> '
- 2026-11-26 15:31:40 EST — c4096 run-2 START load=7.14 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-4096/lfm3_cand1_lut4_C4096 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:31:43 EST — c4096 run-2 END rc=0 wall=2.928s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1674 ms | 16 new tokens | 23.5 tok/s | position 33 of 4096]\n> '
- 2026-11-26 15:31:43 EST — c4096 run-3 START load=7.14 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-4096/lfm3_cand1_lut4_C4096 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:31:46 EST — c4096 run-3 END rc=0 wall=2.828s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1706 ms | 16 new tokens | 24.4 tok/s | position 33 of 4096]\n> '
- 2026-11-26 15:31:46 EST — c4096 run-4 START load=7.13 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-4096/lfm3_cand1_lut4_C4096 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:31:49 EST — c4096 run-4 END rc=0 wall=2.819s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1652 ms | 16 new tokens | 22.3 tok/s | position 33 of 4096]\n> '
- 2026-11-26 15:31:49 EST — c4096 run-5 START load=7.13 cmd=/Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/anec-run /Users/nayte/ane-records-v060-scratch/work/run-4096/lfm3_cand1_lut4_C4096 --model /Users/nayte/ane-records-v060-scratch/work/lfm3-ane-runner-r5/model --tokenizer /Users/nayte/ane-records-v060-scratch/work/tokenizer/tokenizer.json --chat 1 --prompt What is the capital of France? --units ane --max-tokens 32
- 2026-11-26 15:31:52 EST — c4096 run-5 END rc=0 wall=2.795s stdout_sha256=f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2 stdout='The capital of France is Paris, which has been the capital for centuries.\n' stderr='[18 prompt tokens | first token 1665 ms | 16 new tokens | 22.9 tok/s | position 33 of 4096]\n> '
- 2026-11-26 15:31:52 EST — c4096 DONE identical=True hashes=['f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2', 'f2fa123a32ca6e7946be7524dab4b5bf7ba66d1f4a9c232bae6d9555fa1534f2']
- 2026-11-26 15:31:52 EST — c4096 extract deleted
- 2026-11-26 15:31:52 EST — counted runs done timing_verdict=INDICATIVE
- 2026-11-26 15:32:32 EST — N4b powermetrics attempt start
- 2026-11-26 15:32:32 EST — sudo -n true rc=0 err=
- 2026-11-26 15:32:32 EST — powermetrics --help rc=0 excerpt=Usage: powermetrics [-i sample_interval] [-r order] [-t wakeup_cost]

  Gather and display CPU usage statistics (divided into time spent in
  user mode and supervisor mode), timer and interrupt wakeup frequency
  (total and, for near-idle workloads, those that resulted in package
  C-state exits), and on supported platforms, interrupt frequencies
  (categorized by CPU number), package C-state stat
- 2026-11-26 15:32:34 EST — powermetrics started pid=3104
- 2026-11-26 15:33:05 EST — N4b trace run 1 rc=0 wall=31.42s out='The capital of France is Paris, which has been the capital for centuries.\n'
- 2026-11-26 15:33:07 EST — N4b trace run 2 rc=0 wall=1.51s out='The capital of France is Paris, which has been the capital for centuries.\n'
- 2026-11-26 15:33:08 EST — N4b trace run 3 rc=0 wall=1.23s out='The capital of France is Paris, which has been the capital for centuries.\n'
- 2026-11-26 15:33:08 EST — powermetrics finished rc=0
- 2026-11-26 15:33:08 EST — N4b ANE Power samples mW: ['0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0']
- 2026-11-26 15:33:08 EST — N4a cache-filled 4096 attempt start
- 2026-11-26 15:33:08 EST — repo tools dir listing: ['tok.mjs']
- 2026-11-26 15:33:08 EST — N4a tokenizer lib failed: No module named 'tokenizers'; falling back to word-count approximation
- 2026-11-26 15:33:09 EST — N4a run start prompt_tokens_target=None
- 2026-11-26 15:33:44 EST — N4a run rc=1 wall=34.58s stdout='' stderr='anec-run: error: the prompt is 5059 tokens and the context holds 4096\n'
- 2026-11-26 15:33:44 EST — N4 attempts done
- 2026-11-26 15:34:56 EST — N4 attempt 2 start (disclosed retry: N4b sync fix, N4a prompt sized from runner token count)
- 2026-11-26 15:35:34 EST — N4b2 warmup rc=0 wall=33.57s
- 2026-11-26 15:35:34 EST — N4b2 powermetrics started pid=8541
- 2026-11-26 15:35:35 EST — N4b2 loop run 1 rc=0 wall=1.43s stderr='[18 prompt tokens | first token 543 ms | 16 new tokens | 39.2 tok/s | position 33 of 256]\n>'
- 2026-11-26 15:35:37 EST — N4b2 loop run 2 rc=0 wall=1.37s stderr='[18 prompt tokens | first token 525 ms | 16 new tokens | 40.0 tok/s | position 33 of 256]\n>'
- 2026-11-26 15:35:38 EST — N4b2 loop run 3 rc=0 wall=1.29s stderr='[18 prompt tokens | first token 531 ms | 16 new tokens | 48.6 tok/s | position 33 of 256]\n>'
- 2026-11-26 15:35:39 EST — N4b2 loop run 4 rc=0 wall=1.36s stderr='[18 prompt tokens | first token 525 ms | 16 new tokens | 40.2 tok/s | position 33 of 256]\n>'
- 2026-11-26 15:35:41 EST — N4b2 loop run 5 rc=0 wall=1.39s stderr='[18 prompt tokens | first token 530 ms | 16 new tokens | 37.8 tok/s | position 33 of 256]\n>'
- 2026-11-26 15:35:42 EST — N4b2 loop run 6 rc=0 wall=1.39s stderr='[18 prompt tokens | first token 529 ms | 16 new tokens | 39.4 tok/s | position 33 of 256]\n>'
- 2026-11-26 15:35:43 EST — N4b2 loop run 7 rc=0 wall=1.36s stderr='[18 prompt tokens | first token 504 ms | 16 new tokens | 38.6 tok/s | position 33 of 256]\n>'
- 2026-11-26 15:35:45 EST — N4b2 loop run 8 rc=0 wall=1.38s stderr='[18 prompt tokens | first token 508 ms | 16 new tokens | 40.5 tok/s | position 33 of 256]\n>'
- 2026-11-26 15:35:58 EST — N4b2 powermetrics done rc=0
- 2026-11-26 15:35:58 EST — N4b2 ANE Power samples mW: ['383', '1049', '149', '950', '646', '509', '1677', '158', '1013', '430', '662', '951', '67', '977', '582', '879', '818', '324', '1408', '182', '2', '2', '2', '2', '0', '2', '2', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0']
- 2026-11-26 15:35:58 EST — N4a2 run start reps=280 estimated_tokens=3939
- 2026-11-26 15:39:14 EST — N4a2 rc=0 wall=196.77s stdout='The question is a mix of many sentences about "The quick brown fox jumps over the lazy dog near the river bank" and many variations of "near the river\n' stderr='[3939 prompt tokens | first token 158959 ms | 32 new tokens | 26.3 tok/s | position 3970 of 4096]\n> '
- 2026-11-26 15:39:15 EST — N4 attempt 2 done
- 2026-11-26 15:39:36 EST — stats c256: tok/s=[40.0, 41.2, 34.8, 38.2, 39.9] median=39.9 mean=38.82 CI95=[36.64,41.00] first_token_ms=[569, 513, 538, 523, 525]
- 2026-11-26 15:39:36 EST — stats c512: tok/s=[38.2, 38.6, 38.8, 33.1, 38.9] median=38.6 mean=37.52 CI95=[35.34,39.70] first_token_ms=[652, 610, 598, 606, 596]
- 2026-11-26 15:39:36 EST — stats c1024: tok/s=[34.5, 31.7, 35.4, 35.3, 35.9] median=35.3 mean=34.56 CI95=[33.09,36.03] first_token_ms=[806, 748, 755, 810, 757]
- 2026-11-26 15:39:36 EST — stats c2048: tok/s=[30.7, 30.2, 30.6, 33.3, 30.5] median=30.6 mean=31.06 CI95=[29.95,32.17] first_token_ms=[1154, 1108, 1053, 987, 1094]
- 2026-11-26 15:39:36 EST — stats c4096: tok/s=[24.3, 23.5, 24.4, 22.3, 22.9] median=23.5 mean=23.48 CI95=[22.69,24.27] first_token_ms=[1736, 1674, 1706, 1652, 1665]
- 2026-11-26 15:39:36 EST — cleanup removed /Users/nayte/ane-records-v060-scratch/work/lfm3-repo
- 2026-11-26 15:39:36 EST — cleanup removed /Users/nayte/ane-records-v060-scratch/work/runner-extract
- 2026-11-26 15:39:36 EST — cleanup done; keeping evidence/, runs/, RUNLOG.md, profile, profile-repo/, tokenizer/, lfm3-ane-runner-r5/, tools/, scripts
- Thu Nov 26 15:40:06 EST 2026 — cleanup removed own caches: ~/Library/Caches/computeplan (3.9G, e5 bundle cache from computeplan tool) and 5x seg01_dev*.mlmodelc in TMPDIR (~4.0G) created by MLModel.compileModel during this task
