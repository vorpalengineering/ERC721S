// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC721S} from "../src/ERC721S.sol";
import {IERC721S} from "../src/interfaces/IERC721S.sol";

contract ERC721STest is Test {

    //========== Test State ==========

    ERC721S public token;
    address public owner;
    address public fundsRecipient;
    uint256 public pricePerSecond = 11570000000000;
    uint256 public constant minDuration = 1 days;
    uint256 public constant maxDuration = 365 days;

    // ERC721 state
    string public constant NAME = "Test Subscription";
    string public constant SYMBOL = "TEST";

    //========== Setup ==========

    function setUp() public {
        owner = makeAddr("owner");
        fundsRecipient = makeAddr("fundsRecipient");
        
        vm.startPrank(owner);
        token = new ERC721S(
            NAME,
            SYMBOL,
            owner,
            pricePerSecond,
            minDuration,
            maxDuration,
            fundsRecipient
        );
        vm.stopPrank();
    }

    //========== Tests ==========

    function test_InitialState() public view {
        // Check token details
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        
        // Check ownership
        assertEq(token.owner(), owner);
        
        // Check subscription parameters
        assertEq(token.minSubscriptionDuration(), minDuration);
        assertEq(token.maxSubscriptionDuration(), maxDuration);
        assertEq(token.pricePerSecond(), pricePerSecond);
        assertEq(token.fundsRecipient(), fundsRecipient);
        
        // Check initial balance
        assertEq(address(token).balance, 0);
    }

    function test_SetPrice() public {
        uint256 newPricePerSecond = pricePerSecond * 2;

        // Set price
        vm.startPrank(owner);
        token.setPrice(newPricePerSecond);
        vm.stopPrank();

        // Check price
        assertEq(token.pricePerSecond(), newPricePerSecond);
    }

    function test_SetFundsRecipient() public {
        address newFundsRecipient = makeAddr("newFundsRecipient");

        // Set funds recipient
        vm.startPrank(owner);
        token.setFundsRecipient(newFundsRecipient);
        vm.stopPrank(); 

        assertEq(token.fundsRecipient(), newFundsRecipient);
    }

    function test_Subscribe() public {
        // Initialize state
        uint256 duration = 1 days;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund);

        // Subscribe
        vm.startPrank(subscriber);
        vm.expectEmit(true, true, false, true);
        emit IERC721S.SubscriptionStarted(subscriber, token.deriveTokenId(subscriber), block.timestamp, block.timestamp + duration);
        (uint256 tokenId, uint256 expiration) = token.subscribe{value: amountToFund}(subscriber, duration, amountToFund);
        vm.stopPrank();

        // Check balance
        assertEq(address(fundsRecipient).balance, amountToFund);
        assertEq(address(token).balance, 0);
        assertEq(token.balanceOf(subscriber), 1);

        // Check token details
        assertEq(token.ownerOf(tokenId), subscriber);

        // Check expiration
        assertEq(token.expirations(tokenId), expiration);

        // Check subscription is active
        assertEq(token.isSubscriptionActive(tokenId), true);
        assertEq(token.hasActiveSubscription(subscriber), true);
    }

    function test_Subscribe_Reverts_InsufficientFunds() public {
        // Initialize state
        uint256 duration = 1 days;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund - 1);

        // Subscribe    
        vm.startPrank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InsufficientPayment.selector, 
                amountToFund, 
                amountToFund - 1
            )
        );
        token.subscribe{value: amountToFund - 1}(subscriber, duration, amountToFund);
        vm.stopPrank();
    }

    function test_Subscribe_Reverts_InvalidDuration() public {
        // Initialize state
        uint256 duration = maxDuration + 1;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account 
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund);

        // Attempt to subscribe with duration greater than max duration
        vm.startPrank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector, 
                duration
            )
        );
        token.subscribe{value: amountToFund}(subscriber, duration, amountToFund);
        vm.stopPrank();

        // Initialize state
        duration = minDuration - 1;
        amountToFund = token.getSubscriptionCost(duration);

        // Attempt to subscribe with duration less than min duration
        vm.startPrank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector, 
                duration
            )
        );
        token.subscribe{value: amountToFund}(subscriber, duration, amountToFund);
        vm.stopPrank();
    }

    function test_Subscribe_Reverts_CostMismatch() public {
        // Initialize state
        uint256 duration = 1 days;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund);

        // Change price
        vm.startPrank(owner);
        token.setPrice(pricePerSecond * 2);
        vm.stopPrank();

        // Subscribe with incorrect amount
        vm.startPrank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.CostMismatch.selector, 
                amountToFund * 2, 
                amountToFund
            )
        );
        token.subscribe{value: amountToFund}(subscriber, duration, amountToFund);
        vm.stopPrank();
    }
    
    function test_Withdraw() public {
        // Initialize state
        uint256 duration = 1 days;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account 
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund);

        // Change funds recipient to token address
        vm.startPrank(owner);
        token.setFundsRecipient(address(token));
        vm.stopPrank();

        // Check pre-withdraw balances
        assertEq(address(owner).balance, 0);
        assertEq(address(token).balance, 0);
        assertEq(address(fundsRecipient).balance, 0);
        assertEq(address(subscriber).balance, amountToFund);

        // Subscribe
        vm.startPrank(subscriber);
        token.subscribe{value: amountToFund}(subscriber, duration, amountToFund);
        vm.stopPrank(); 

        // Withdraw
        vm.startPrank(owner);
        token.withdraw();
        vm.stopPrank();

        // Check post-withdraw balances
        assertEq(address(owner).balance, amountToFund);
        assertEq(address(token).balance, 0);
        assertEq(address(fundsRecipient).balance, 0);
        assertEq(address(subscriber).balance, 0);
    }
}