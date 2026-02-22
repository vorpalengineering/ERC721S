// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC721S} from "../src/ERC721S.sol";

contract ERC721SScript is Script {
    
    ERC721S public token;
    address public owner;
    address public fundsRecipient;
    uint256 public pricePerSecond = 11570000000000;
    uint256 public constant minDuration = 1 days;
    uint256 public constant maxDuration = 365 days;
    uint256 public constant maxAccumulatedDuration = 730 days;
    string public constant name = "Test Subscription";
    string public constant symbol = "TEST";

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new ERC721S(
            name,
            symbol,
            owner,
            pricePerSecond,
            minDuration,
            maxDuration,
            maxAccumulatedDuration,
            fundsRecipient
        );

        vm.stopBroadcast();
    }
}
