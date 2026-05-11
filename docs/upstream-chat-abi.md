# §5.1.6 v3 local LLM — upstream tracker

**Status (May 2026): SHIPPED.** Upstream CrispASR exposed the
chat ABI (`crispasr_chat_*` + Dart binding `CrispasrChatSession`
in `flutter/crispasr/lib/src/chat.dart`), and the CrisperWeaver
side landed alongside as §5.1.6 v3 — `LocalLlmCleanupService` +
worker-isolate transport, three-mode Tidy / Summarize selector,
Settings → Local LLM cleanup. See CHANGELOG.md → "Unreleased"
for the user-facing summary. The notes below are kept as
historical context for the design conversation. Next steps live
in PLAN.md → §5.1.6 v3.1 (curated chat-model catalogue).

PLAN §5.1.6 v3 ("Tidy transcript with local LLM") was gated on
upstream CrispASR work that exposes llama.cpp's chat machinery
as a public C ABI on `libcrispasr`. Until that shipped, the
deterministic v1 + BYOK cloud v2 (already in main) were the
shipped options.

**Canonical brief:** [`CrispASR/docs/prompts/chat-abi.md`](../../CrispASR/docs/prompts/chat-abi.md)
— covers what exists today (vendored llama.cpp in
`examples/talk-llama/`, no public chat surface), goal C ABI
(`crispasr_chat_open / _close / _generate` + streaming variant),
the full deliverable list (ABI, CLI, server endpoint, Dart
wrapper, tests), design considerations (threading, KV cache,
sampler config, GGML pipeline cache reuse), what to avoid (no
second copy of ggml, don't break audio-LLM backends, no SDL2 on
libcrispasr proper), and phasing (0 build extraction → 7 the
CrisperWeaver follow-up session).

**Where this lands here once upstream is done:**

1. New `lib/services/local_llm_cleanup_service.dart` that wraps
   the `crispasr.chat*` Dart API the upstream work produces.
   Mirror the existing `CloudLlmCleanupService` surface so the
   Tidy dialog's `runLlmPass` toggle can route to either path
   without UI duplication.
2. Extend the Tidy dialog to offer three modes for the LLM
   pass: off / cloud (existing BYOK) / local. Pick local by
   default once a chat-capable model is loaded.
3. Add a chat-model picker to Settings → Cloud LLM cleanup
   (rename that section once local lands).
4. Tests against the upstream's mock-session pattern.

**Don't start the CrisperWeaver side without the upstream
ABI.** Whatever local-LLM surface we wire here must be the same
shape as whatever lands upstream, and the upstream design is
where the real interface decisions get made.
