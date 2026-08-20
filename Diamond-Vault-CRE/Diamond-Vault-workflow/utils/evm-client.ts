import {
    decodeEventLog,
    decodeFunctionResult,
    encodeFunctionData,
    getAddress,
    bytesToHex,
    type Address,
    type Hex,
} from "viem";

export const STRATEGY_HARVESTED_EVENT_ABI = [
    {
        type: "event",
        name: "StrategyHarvested",
        inputs: [
            {
                indexed: true,
                name: "strategyId",
                type: "bytes32",
            },
            {
                indexed: false,
                name: "previousDebt",
                type: "uint256",
            },
            {
                indexed: false,
                name: "reportedDebt",
                type: "uint256",
            },
            {
                indexed: false,
                name: "gain",
                type: "uint256",
            },
            {
                indexed: false,
                name: "loss",
                type: "uint256",
            },
        ],
    },
] as const;

export const STRATEGY_KEEPER_ABI = [
    {
        name: "keeper",
        type: "function",
        inputs: [],
        outputs: [{ type: "address", name: "keeper_" }],
        stateMutability: "view",
    },
    {
        name: "keeperHarvestStrategy",
        type: "function",
        inputs: [{ type: "bytes32", name: "strategyId" }],
        outputs: [
            {type: "uint256", name: "reportedAssets"},
            {type: "uint256", name: "gain"},
            {type: "uint256", name: "loss"},
        ],
        stateMutability: "nonpayable",
    },
] as const;

export type KeeperHarvestResult = {
    reportedAssets: bigint;
    gain: bigint;
    loss: bigint;
};

export type StrategyHarvestedEvent = {
    strategyId: Hex;
    previousDebt: bigint;
    reportedDebt: bigint;
    gain: bigint;
    loss: bigint;
};

export function normalizeAddress(address: string): Address {
    return getAddress(address) as Address;
}

export function encodeKeeperCall(): Hex {
    return encodeFunctionData({
        abi: STRATEGY_KEEPER_ABI,
        functionName: "keeper",
    });
}

export function decodeKeeperResult(data: Hex): Address {
    const keeper = decodeFunctionResult({
        abi: STRATEGY_KEEPER_ABI,
        functionName: "keeper",
        data,
    });

    return normalizeAddress(keeper);
}

export function encodeKeeperHarvestCall(strategyId: Hex): Hex {
    return encodeFunctionData({
        abi: STRATEGY_KEEPER_ABI,
        functionName: "keeperHarvestStrategy",
        args: [strategyId],
    });
}

export function decodeKeeperHarvestResult(data: Hex): KeeperHarvestResult {
    const [reportedAssets, gain, loss] = decodeFunctionResult({
        abi: STRATEGY_KEEPER_ABI,
        functionName: "keeperHarvestStrategy",
        data,
    });

    return {
        reportedAssets,
        gain,
        loss,
    };
}

export function decodeStrategyHarvestedLog(
    log: {
        topics: Uint8Array[];
        data: Uint8Array;
    }
): StrategyHarvestedEvent | null {
    try {
        const topics = log.topics.map((topic) => bytesToHex(topic));

        if (topics.length === 0) {
            return null;
        }
        
        const decoded = decodeEventLog({
            abi: STRATEGY_HARVESTED_EVENT_ABI,
            topics: topics as [Hex, ...Hex[]],
            data: bytesToHex(log.data),
        });

        if (decoded.eventName !== "StrategyHarvested") {
            return null;
        }

        return {
            strategyId: decoded.args.strategyId,
            previousDebt: decoded.args.previousDebt,
            reportedDebt: decoded.args.reportedDebt,
            gain: decoded.args.gain,
            loss: decoded.args.loss,
        };
    } catch {
        return null;
    }
}
