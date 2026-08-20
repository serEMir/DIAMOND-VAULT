// workflows/harvest.ts
import {
    getNetwork,
    prepareReportRequest,
    type Runtime,
    cre,
} from "@chainlink/cre-sdk";

import { bytesToHex, zeroAddress, type Hex } from "viem";
import type { HarvestConfig } from "./config";
import {
    encodeKeeperHarvestCall,
    normalizeAddress,
    decodeStrategyHarvestedLog
} from "./utils/evm-client";


export type HarvestResult = {
    status: "submitted";
    strategyId: string;
    txHash?: string;
    receiptStatus: "unavailable" | "pending" | "confirmed" | "confirmed_without_harvest_event";
    reportedAssets?: bigint;
    gain?: bigint;
    loss?: bigint;
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
    const keeperAddress = normalizeAddress(config.keeperAddress || zeroAddress);
    const receiverAddress = normalizeAddress(config.receiverAddress || zeroAddress);

    if (!keeperAddress || keeperAddress === zeroAddress) {
        throw new Error("Keeper address not configured");
    }

    if (!receiverAddress || receiverAddress === zeroAddress) {
        throw new Error("Receiver address not configured");
    }

    const evmClient = new cre.capabilities.EVMClient(network.chainSelector.selector);

    const callData = encodeKeeperHarvestCall(config.strategyId as Hex);
    runtime.log(`harvest calldata encoded - strategyId: ${config.strategyId}, calldata: ${callData}`);

    // Create and submit report
    const report = runtime.report(prepareReportRequest(callData)).result();

    runtime.log(`report created - submitting to receiver: ${receiverAddress}`);

    const writeResult = evmClient.writeReport(runtime, {
        receiver: receiverAddress,
        report,
    }).result();

    if (writeResult.txStatus !== 2) {
        throw new Error(
            `writeReport failed with txStatus=${writeResult.txStatus}: ${writeResult.errorMessage ?? "no error message"}`
        );
    }

    if (writeResult.receiverContractExecutionStatus === 1) {
        throw new Error("CRE receiver reverted while executing the harvest report");
    }

    const txHash = writeResult.txHash ? bytesToHex(writeResult.txHash) : undefined;
    if (!txHash) {
        runtime.log(`harvest report submitted - strategyId: ${config.strategyId}`);
        return {
            status: "submitted",
            strategyId: config.strategyId,
            receiptStatus: "unavailable",
        };
    }

    const receiptReply = evmClient.getTransactionReceipt(runtime, {hash: txHash}).result();
    if (!receiptReply.receipt) {
        runtime.log(`harvest submitted - transaction pending: ${txHash}`);
        return {
            status: "submitted",
            strategyId: config.strategyId,
            txHash,
            receiptStatus: "pending",
        };
    }

    if (receiptReply.receipt.status !== 1n) {
        throw new Error(`harvest transaction reverted: ${txHash}`);
    }

    for (const log of receiptReply.receipt.logs) {
        const harvest = decodeStrategyHarvestedLog(log);
        if (harvest) {
            runtime.log(
                `Harvested: debt=${harvest.reportedDebt} gain=${harvest.gain} loss=${harvest.loss}`
            );
            return {
                status: "submitted",
                strategyId: harvest.strategyId,
                reportedAssets: harvest.reportedDebt,
                gain: harvest.gain,
                loss: harvest.loss,
                txHash,
                receiptStatus: "confirmed",
            };
        }
    }

    runtime.log(`harvest submitted but StrategyHarvested was not in receipt logs: ${txHash}`);
    return {
        status: "submitted",
        strategyId: config.strategyId,
        txHash,
        receiptStatus: "confirmed_without_harvest_event",
    };
}
