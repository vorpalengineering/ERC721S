// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC721S} from "../src/ERC721S.sol";

contract ERC721SScript is Script {
    ERC721S public token;
    address public owner;
    address public fundsRecipient;
    uint256 public pricePerSecond = 11570000000000;
    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MAX_DURATION = 365 days;
    

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new ERC721S(
            "Test Subscription",
            "TEST",
            owner,
            pricePerSecond,
            MIN_DURATION,
            MAX_DURATION,
            fundsRecipient
        );

        vm.stopBroadcast();
    }
}
