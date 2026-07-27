// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {CREReceiver} from "../src/cre/CREReceiver.sol";
import {IStrategyKeeper} from "../src/strategy/interfaces/IStrategyKeeper.sol";
import {IStrategyManager} from "../src/strategy/interfaces/IStrategyManager.sol";

contract DummyDiamond {
    function keeperHarvestStrategy(bytes32) external pure returns (uint256, uint256, uint256) {
        return (0, 0, 0);
    }

    function allocateToStrategy(bytes32, uint256) external pure returns (uint256) {
        return 1;
    }

    function freeFundsFromStrategy(bytes32, uint256) external pure returns (uint256, uint256) {
        return (1, 0);
    }
}

contract CREReceiverUnitTest is Test {
    CREReceiver receiver;
    DummyDiamond diamond;
    address forwarder = address(0xF00D);

    function setUp() public {
        diamond = new DummyDiamond();
        receiver = new CREReceiver(address(diamond), forwarder);
    }

    function testRejectsInvalidPayload() public {
        bytes memory metadata = "";
        bytes memory badReport = hex"deadbeef"; // 4 bytes, invalid

        vm.prank(forwarder);
        vm.expectRevert();
        receiver.onReport(metadata, badReport);
    }

    function testAcceptsKeeperHarvestSelector() public {
        bytes memory metadata = "";
        bytes32 sid = bytes32(uint256(1));
        bytes memory report = abi.encodePacked(IStrategyKeeper.keeperHarvestStrategy.selector, sid);

        vm.prank(forwarder);
        // should not revert
        receiver.onReport(metadata, report);
    }

    function testAcceptsAllocateAndFreeSelectors() public {
        bytes memory metadata = "";
        bytes32 sid = bytes32(uint256(2));

        bytes memory alloc = abi.encodeWithSelector(IStrategyManager.allocateToStrategy.selector, sid, uint256(1000));
        vm.prank(forwarder);
        receiver.onReport(metadata, alloc);

        bytes memory freeCall =
            abi.encodeWithSelector(IStrategyManager.freeFundsFromStrategy.selector, sid, uint256(500));
        vm.prank(forwarder);
        receiver.onReport(metadata, freeCall);
    }
}
