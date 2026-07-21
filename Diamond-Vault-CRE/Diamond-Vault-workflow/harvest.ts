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
    
    // Debug: print detailed diagnostics for writeResult (keys, types, lengths)
    try {
        const keys = Object.keys(writeResult as Record<string, unknown>);
        runtime.log(`writeResult.keys: ${keys.join(",")}`);

        for (const k of keys) {
            const v = (writeResult as any)[k];
            if (v === null || v === undefined) {
                runtime.log(`${k}: null`);
                continue;
            }

            if (v instanceof Uint8Array) {
                try {
                    runtime.log(`${k}: Uint8Array length=${v.length} hex=${bytesToHex(v)}`);
                } catch {
                    runtime.log(`${k}: Uint8Array length=${v.length}`);
                }
                continue;
            }

            if (Array.isArray(v)) {
                runtime.log(`${k}: Array length=${v.length}`);
                continue;
            }

            const t = typeof v;
            if (t === "object") {
                try {
                    runtime.log(`${k}: ${JSON.stringify(v)}`);
                } catch {
                    runtime.log(`${k}: [object]`);
                }
            } else {
                runtime.log(`${k}: ${String(v)}`);
            }
        }
    } catch (err) {
        runtime.log(`writeResult debug failed: ${String(err)}`);
    }

    if (typeof (writeResult as any).txHash !== "undefined") {
        const txHashValue = (writeResult as any).txHash;
        if (txHashValue instanceof Uint8Array) {
            runtime.log(`txHash (raw): ${bytesToHex(txHashValue)}`);
        } else {
            runtime.log(`txHash: ${String(txHashValue)}`);
        }
    } else {
        runtime.log("txHash: undefined");
    }

    if (typeof (writeResult as any).errorMessage !== "undefined") {
        runtime.log(`errorMessage: ${String((writeResult as any).errorMessage)}`);
    }

    const txHash = writeResult.txHash ? bytesToHex(writeResult.txHash) : undefined;

    if (!txHash) {
        runtime.log("writeResult has no txHash; this may be a simulator-only response.");
        if (writeResult.txStatus !== 2) {
            throw new Error(`writeReport failed with txStatus=${writeResult.txStatus}`);
        }
        if (writeResult.receiverContractExecutionStatus !== 0) {
            throw new Error(`receiver execution failed with status=${writeResult.receiverContractExecutionStatus}`);
        }

        runtime.log(`harvest report submitted - strategyId: ${config.strategyId}`);
        return {
            status: "success",
            strategyId: config.strategyId,
            reportedAssets: 0n,
            gain: 0n,
            loss: 0n,
            txHash: "simulation",
        };
    }

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