// workflows/harvest.ts
import {
    getNetwork,
    prepareReportRequest,
    type Runtime,
    cre,
} from "@chainlink/cre-sdk";

import { bytesToHex, zeroAddress, type Address, type Hex } from "viem";
import type { HarvestConfig } from "./config";
import {
    encodeKeeperHarvestCall,
    normalizeAddress,
    decodeStrategyHarvestedLog
} from "./utils/evm-client";

// export type HarvestResult = {
//     status: "submitted";
//     strategyId: string;
// };

export type HarvestResult = {
    status: "success";
    strategyId: string;
    reportedAssets: bigint;
    gain: bigint;
    loss: bigint;
    txHash: string;
};

export function harvestCallback(runtime: Runtime<HarvestConfig>): HarvestResult {
    const config = runtime.config;

    runtime.log(
        `harvest triggered - strategyId: ${config.strategyId}, chain: ${config.chainSelectorName}`
    );

    // Get network configuration
    const network = getNetwork({
        chainFamily: "evm",
        chainSelectorName: config.chainSelectorName,
        isTestnet: config.isTestnet,
    });

    if (!network) {
        throw new Error(`Unsupported chain: ${config.chainSelectorName}`);
    }

    // Normalize addresses
    const diamondAddress = normalizeAddress(config.diamondAddress);
    const keeperAddress = normalizeAddress(config.keeperAddress || zeroAddress);
    const receiverAddress = normalizeAddress(config.receiverAddress || zeroAddress);

    if (!keeperAddress || keeperAddress === zeroAddress) {
        throw new Error("Keeper address not configured");
    }

    if (!receiverAddress || receiverAddress === zeroAddress) {
        throw new Error("Receiver address not configured");
    }

    // Create EVM client
    const evmClient = new cre.capabilities.EVMClient(network.chainSelector.selector);

    // Encode the harvest call
    const harvestCallData = encodeKeeperHarvestCall(config.strategyId as Hex);

    runtime.log(
        `harvest calldata encoded - strategyId: ${config.strategyId}, calldata: ${harvestCallData}`
    );

    // Create and submit report
    const report = runtime.report(prepareReportRequest(harvestCallData)).result();

    runtime.log(`report created - submitting to receiver: ${receiverAddress}`);

    const writeResult = evmClient
        .writeReport(runtime, {
            receiver: receiverAddress,
            report,
        })
        .result();
    
    if (!writeResult.txHash) {
    throw new Error("writeReport returned no transaction hash");
    }

    const txHash = bytesToHex(writeResult.txHash);

    runtime.log(`harvest report submitted - strategyId: ${config.strategyId}`);

    const receipt = evmClient
        .getTransactionReceipt(runtime, {
            hash: txHash,
        })
        .result();
    
    if (!receipt.receipt) {
    throw new Error("No receipt data returned yet");
    }
    
    for (const log of receipt.receipt.logs) {
        const harvest = decodeStrategyHarvestedLog(log);

        if (harvest) {
            runtime.log(
                `Harvested: debt=${harvest.reportedDebt} gain=${harvest.gain} loss=${harvest.loss}`
            );
            return {
                status: "success",
                strategyId: harvest.strategyId,
                reportedAssets: harvest.reportedDebt,
                gain: harvest.gain,
                loss: harvest.loss,
                txHash,
            };
        }
    }
    throw new Error(
    `StrategyHarvested event not found in transaction receipt ${txHash}`
    );
}