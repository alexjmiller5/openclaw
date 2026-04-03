import { resolveAgentMaxConcurrent, resolveSubagentMaxConcurrent } from "../config/agent-limits.js";
import type { loadConfig } from "../config/config.js";
import { setCommandLaneConcurrency } from "../process/command-queue.js";
import { CommandLane } from "../process/lanes.js";

export function applyGatewayLaneConcurrency(cfg: ReturnType<typeof loadConfig>) {
  setCommandLaneConcurrency(CommandLane.Cron, cfg.cron?.maxConcurrentRuns ?? 1);
  setCommandLaneConcurrency(CommandLane.Main, resolveAgentMaxConcurrent(cfg));
  setCommandLaneConcurrency(CommandLane.Subagent, resolveSubagentMaxConcurrent(cfg));
  // Nested lane is used by hook-dispatched cron workers (resolveGlobalLane remaps
  // "cron" → Nested to avoid deadlocking the cron lane). Without an explicit
  // concurrency limit, it defaults to 1 — serializing all workers.
  // Use the same concurrency as the subagent lane.
  setCommandLaneConcurrency(CommandLane.Nested, resolveSubagentMaxConcurrent(cfg));
}
