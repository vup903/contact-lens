/// Generative LLM enrichment: note summarization/tagging and query parsing.
///
/// Default path is the pure-Dart [HeuristicLlmAdapter]; [createLlmAdapter] opts
/// into the remote [ClaudeLlmAdapter] (wrapped with heuristic fallback) when an
/// API key is configured and cloud enrichment is enabled.
library;

export 'claude_llm_adapter.dart';
export 'heuristic_llm_adapter.dart';
export 'llm_adapter.dart';
export 'llm_config.dart';
