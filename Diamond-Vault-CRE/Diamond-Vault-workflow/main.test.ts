import { describe, expect, test } from "bun:test";
import { HarvestConfigSchema } from "./config";
// import { initWorkflow } from "./main";

describe("config", () => {
  test("accepts valid harvest config", () => {
    const config = HarvestConfigSchema.parse({
      chainSelectorName: "ethereum-testnet-sepolia",
      isTestnet: true,
      diamondAddress: "0x0000000000000000000000000000000000000000",
      strategyId:
        "0x0000000000000000000000000000000000000000000000000000000000000000",
      keeperAddress: "0x0000000000000000000000000000000000000000",
      cronSchedule: "*/30 * * * * *",
    });

    expect(config.chainSelectorName).toBe("ethereum-testnet-sepolia");
  });
});

// describe("initWorkflow", () => {
//   test("creates one cron handler", () => {
//     const config = HarvestConfigSchema.parse({
//       chainSelectorName: "ethereum-testnet-sepolia",
//       isTestnet: true,
//       diamondAddress: "0x0000000000000000000000000000000000000000",
//       strategyId:
//         "0x0000000000000000000000000000000000000000000000000000000000000000",
//       keeperAddress: "0x0000000000000000000000000000000000000000",
//       cronSchedule: "*/30 * * * * *",
//     });

//     const workflow = initWorkflow(config);

//     expect(workflow).toHaveLength(1);
//   });
// });