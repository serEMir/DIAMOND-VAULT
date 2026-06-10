import { cre, Runner, type Runtime } from "@chainlink/cre-sdk";

import {
  HarvestConfigSchema,
  type HarvestConfig,
  type HarvestConfigInput,
} from "./config";

import { harvestCallback } from "./harvest";

function initWorkflow(config: HarvestConfig) {
  const cron = new cre.capabilities.CronCapability();

  return [
    cre.handler(
      cron.trigger({ schedule: config.cronSchedule }),
      (runtime: Runtime<HarvestConfig>) => {
        return harvestCallback(runtime);
      },
    ),
  ];
}

export async function main() {
  const runner = await Runner.newRunner<HarvestConfig, HarvestConfigInput>({
    configSchema: HarvestConfigSchema,
  });

  await runner.run(async (config: HarvestConfig) => {
    return initWorkflow(config);
  });
}