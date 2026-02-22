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
    uint256 public constant maxAccumulatedDuration = 730 days;

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
            maxAccumulatedDuration,
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
        assertEq(token.minDuration(), minDuration);
        assertEq(token.maxDuration(), maxDuration);
        assertEq(token.maxAccumulatedDuration(), maxAccumulatedDuration);
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
        (uint256 tokenId, uint256 expiration) = token.subscribe{value: amountToFund}(subscriber, duration);
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

    function test_Subscribe_Reverts_InvalidPayment() public {
        // Initialize state
        uint256 duration = 1 days;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund);

        // Subscribe with insufficient funds
        vm.startPrank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidPayment.selector,
                amountToFund,
                amountToFund - 1
            )
        );
        token.subscribe{value: amountToFund - 1}(subscriber, duration);
        vm.stopPrank();
    }

    function test_Subscribe_Reverts_InvalidDuration() public {
        // Initialize state — compute cost manually since getSubscriptionCost now validates bounds
        uint256 duration = maxDuration + 1;
        uint256 amountToFund = duration * pricePerSecond;

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
        token.subscribe{value: amountToFund}(subscriber, duration);
        vm.stopPrank();

        // Initialize state
        duration = minDuration - 1;
        amountToFund = duration * pricePerSecond;

        // Attempt to subscribe with duration less than min duration
        vm.startPrank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector,
                duration
            )
        );
        token.subscribe{value: amountToFund}(subscriber, duration);
        vm.stopPrank();
    }

    function test_GetSubscriptionCost_Reverts_InvalidDuration() public {
        // Attempt to get cost for duration greater than max duration
        uint256 duration = maxDuration + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector,
                duration
            )
        );
        token.getSubscriptionCost(duration);

        // Attempt to get cost for duration less than min duration
        duration = minDuration - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector,
                duration
            )
        );
        token.getSubscriptionCost(duration);
    }

    function test_SetDurationBounds_Reverts_ZeroMinDuration() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector,
                0
            )
        );
        token.setDurationBounds(0, maxDuration);
        vm.stopPrank();
    }

    function test_SetDurationBounds_Reverts_ZeroMaxDuration() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector,
                0
            )
        );
        token.setDurationBounds(1, 0);
        vm.stopPrank();
    }

    function test_SetDurationBounds_Reverts_MaxDurationExceedsMaxAccumulatedDuration() public {
        uint256 newMaxDuration = maxAccumulatedDuration + 1;

        // Attempt to set max duration greater than max accumulated duration
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector,
                newMaxDuration
            )
        );
        token.setDurationBounds(minDuration, newMaxDuration);
        vm.stopPrank();
    }

    function test_Subscribe_Reverts_InvalidPayment_AfterPriceChange() public {
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

        // Subscribe with amount based on old price
        vm.startPrank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidPayment.selector,
                amountToFund * 2,
                amountToFund
            )
        );
        token.subscribe{value: amountToFund}(subscriber, duration);
        vm.stopPrank();
    }
    
    function test_Withdraw() public {
        // Initialize state
        uint256 duration = 1 days;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund);

        // Change funds recipient to token address so funds accumulate in contract
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
        token.subscribe{value: amountToFund}(subscriber, duration);
        vm.stopPrank();

        // Change funds recipient to a real address before withdrawing
        vm.startPrank(owner);
        token.setFundsRecipient(fundsRecipient);
        token.withdraw();
        vm.stopPrank();

        // Check post-withdraw balances — funds go to fundsRecipient, not owner
        assertEq(address(owner).balance, 0);
        assertEq(address(token).balance, 0);
        assertEq(address(fundsRecipient).balance, amountToFund);
        assertEq(address(subscriber).balance, 0);
    }

    function test_SetMaxAccumulatedDuration() public {
        uint256 newMaxAccumulatedDuration = maxAccumulatedDuration * 2;

        // Set max accumulated duration
        vm.startPrank(owner);
        token.setMaxAccumulatedDuration(newMaxAccumulatedDuration);
        vm.stopPrank();

        // Check max accumulated duration
        assertEq(token.maxAccumulatedDuration(), newMaxAccumulatedDuration);
    }

    function test_SetMaxAccumulatedDuration_Reverts_LessThanMaxDuration() public {
        uint256 newMaxAccumulatedDuration = maxDuration - 1;

        // Attempt to set max accumulated duration less than max duration
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector,
                newMaxAccumulatedDuration
            )
        );
        token.setMaxAccumulatedDuration(newMaxAccumulatedDuration);
        vm.stopPrank();
    }

    function test_Subscribe_Extend() public {
        // Initialize state
        uint256 duration = 30 days;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund * 2);

        // Subscribe
        vm.startPrank(subscriber);
        (uint256 tokenId, uint256 firstExpiration) = token.subscribe{value: amountToFund}(subscriber, duration);

        // Extend subscription
        vm.expectEmit(true, true, false, true);
        emit IERC721S.SubscriptionExtended(subscriber, tokenId, firstExpiration + duration);
        (uint256 extendedTokenId, uint256 extendedExpiration) = token.subscribe{value: amountToFund}(subscriber, duration);
        vm.stopPrank();

        // Check token id is the same
        assertEq(extendedTokenId, tokenId);

        // Check expiration was extended from previous expiration
        assertEq(extendedExpiration, firstExpiration + duration);
        assertEq(token.expirations(tokenId), extendedExpiration);

        // Check subscription is still active
        assertEq(token.isSubscriptionActive(tokenId), true);
        assertEq(token.hasActiveSubscription(subscriber), true);

        // Check no duplicate token was minted
        assertEq(token.balanceOf(subscriber), 1);
    }

    function test_Subscribe_Extend_Reverts_ExceedsMaxAccumulatedDuration() public {
        // Initialize state
        uint256 duration = maxDuration;
        uint256 amountToFund = token.getSubscriptionCost(duration);

        // Make and fund subscriber account
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, amountToFund * 3);

        // Subscribe for max duration
        vm.startPrank(subscriber);
        token.subscribe{value: amountToFund}(subscriber, duration);

        // Extend for max duration again (now at 730 days remaining, which is >= maxAccumulatedDuration)
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721S.InvalidDuration.selector,
                duration
            )
        );
        token.subscribe{value: amountToFund}(subscriber, duration);
        vm.stopPrank();
    }

    function test_Subscribe_Extend_AtMaxAccumulatedDuration() public {
        // Initialize state — extend just under the cap
        uint256 firstDuration = maxDuration;
        uint256 firstCost = token.getSubscriptionCost(firstDuration);

        // The remaining time after first subscribe is maxDuration (365 days)
        // maxAccumulatedDuration is 730 days, so we can extend by up to 365 days - 1 second
        uint256 secondDuration = maxDuration - 1 seconds;
        uint256 secondCost = token.getSubscriptionCost(secondDuration);

        // Make and fund subscriber account
        address subscriber = makeAddr("subscriber");
        vm.deal(subscriber, firstCost + secondCost);

        // Subscribe for max duration
        vm.startPrank(subscriber);
        token.subscribe{value: firstCost}(subscriber, firstDuration);

        // Extend just under the cap — should succeed
        token.subscribe{value: secondCost}(subscriber, secondDuration);
        vm.stopPrank();

        // Check total accumulated duration
        uint256 tokenId = token.deriveTokenId(subscriber);
        uint256 totalRemaining = token.expirations(tokenId) - block.timestamp;
        assertEq(totalRemaining, firstDuration + secondDuration);
        assertEq(token.hasActiveSubscription(subscriber), true);
    }
}