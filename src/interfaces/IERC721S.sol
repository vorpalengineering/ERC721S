// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title IERC721S
 * @dev Interface for the ERC721S Subscription Token Contract
 */
interface IERC721S is IERC721 {
    
    //========== Events ==========
    
    event SubscriptionStarted(address indexed account, uint256 indexed tokenId, uint256 startTime, uint256 expiration);
    event SubscriptionExtended(address indexed account, uint256 indexed tokenId, uint256 expiration);
    event SubscriptionPriceUpdated(uint256 newPriceInWei);
    event FundsRecipientUpdated(address newFundsRecipient);
    event PaymentReceived(address indexed account, address indexed paidBy, uint256 amount);
    event DurationBoundsUpdated(uint256 newMinDuration, uint256 newMaxDuration);

    //========== Errors ==========

    error InvalidAddress(string parameterName, address account);
    error CostMismatch(uint256 calculated, uint256 required);
    error InsufficientPayment(uint256 required, uint256 received);
    error InvalidDuration(uint256 duration);
    error TokenNonTransferable();
    error NativeTransferFailed(address recipient, uint256 amount);

    //========== State Variables ==========

    function minDuration() external view returns (uint256);
    function maxDuration() external view returns (uint256);
    function pricePerSecond() external view returns (uint256);
    function fundsRecipient() external view returns (address);
    function expirations(uint256 tokenId) external view returns (uint256);

    //========== Functions ==========

    /**
     * @notice Set the duration bounds for the subscription.
     * @param newMinDuration The minimum duration of the subscription in seconds.
     * @param newMaxDuration The maximum duration of the subscription in seconds.
     */
    function setDurationBounds(uint256 newMinDuration, uint256 newMaxDuration) external;

    /**
     * @notice Set the price of the subscription. Denominated in wei per second.
     * @param newPricePerSecond New price of the subscription in wei
     */
    function setPrice(uint256 newPricePerSecond) external;

    /**
     * @notice Set the address that receives funds.
     * @param newFundsRecipient The address that receives funds
     */
    function setFundsRecipient(address newFundsRecipient) external;

    /**
     * @notice Create or extend a subscription.
     * @param subscriptionOwner The account that will own the subscription.
     * @param durationInSeconds The duration of the subscription in seconds.
     * @param totalCostInWei The total cost of the subscription in wei.
     * @return tokenId The id of the subscription token.
     * @return expiration The expiration timestamp of the subscription.
     */
    function subscribe(
        address subscriptionOwner,
        uint256 durationInSeconds,
        uint256 totalCostInWei
    ) external payable returns (uint256 tokenId, uint256 expiration);

    /**
     * @notice Withdraw the contract balance.
     */
    function withdraw() external;

    /**
     * @notice Calculate the cost of a subscription.
     * @param durationInSeconds The duration of the subscription in seconds
     * @return uint256 The cost of the subscription in wei for the given duration
     */
    function getSubscriptionCost(uint256 durationInSeconds) external view returns (uint256);

    /**
     * @notice Derive the tokenId from an account address.
     * @param account The account to derive the tokenId from
     * @return uint256 The tokenId derived from the account address
     */
    function deriveTokenId(address account) external pure returns (uint256);

    /**
     * @notice Check if an account has an active subscription.
     * @param account The account to check
     * @return bool True if the account has an active subscription, false otherwise
     */
    function hasActiveSubscription(address account) external view returns (bool);

    /**
     * @notice Check if a subscription token is active.
     * @param tokenId The tokenId of the subscription
     * @return bool True if the subscription is active, false otherwise
     */
    function isSubscriptionActive(uint256 tokenId) external view returns (bool);
}
