import {z} from "zod";

const addressSchema = z
    .string()
    .regex(/^0x[a-fA-F0-9]{40}$/, "Expected a 20-byte EVM address");

const bytes32Schema = z
    .string()
    .regex(/^0x[a-fA-F0-9]{64}$/, "Expected a 32-byte hex string");


export const HarvestConfigSchema = z.object({
    chainSelectorName: z.string().min(1),
    isTestnet: z.boolean().default(true),
    diamondAddress: addressSchema,
    strategyId: bytes32Schema,
    keeperAddress: addressSchema.optional(),
    receiverAddress: addressSchema.optional(),
    cronSchedule: z.string().min(1), // e.g. "0 0 * * *"
});

export type HarvestConfigInput = z.input<typeof HarvestConfigSchema>;
export type HarvestConfig = z.output<typeof HarvestConfigSchema>;

export function loadConfig(rawConfig: unknown): HarvestConfig {
    return HarvestConfigSchema.parse(rawConfig);
}

export function loadConfigFromFile(filePath: string): HarvestConfig {
    const fs = require("fs");
    const rawData = fs.readFileSync(filePath, "utf-8");
    return loadConfig(JSON.parse(rawData));
}