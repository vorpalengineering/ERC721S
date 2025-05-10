// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IERC721S.sol";

/**
 * @title ERC721S Subscription Token Contract
 * @dev A contract for creating and managing ERC721 Subscription Tokens.
 * The token id is derived from the account address, and the token is minted
 * when the account has no existing subscription token. Subscribing again when
 * the subscription is active will extend the expiration. Subscription Tokens
 * are non-transferable. Sufficient funds must be sent when subscribing.
 */
contract ERC721S is IERC721S, ERC721, Ownable2Step, ReentrancyGuard {

    //========== State ==========

    /// @notice Minimum subscription duration in seconds
    uint256 public minDuration;
    
    /// @notice Maximum subscription duration in seconds
    uint256 public maxDuration;

    /// @notice cost in wei per second of a subscription
    uint256 public pricePerSecond;

    /// @notice address that receives funds
    address public fundsRecipient;

    /// @notice subscription tokenId => expiration timestamp
    mapping(uint256 => uint256) public expirations;

    //========== Constructor ==========
    
    /**
     * @notice ERC721S Constructor
     * @param _name_ The name of the token (ERC721)
     * @param _symbol_ The symbol of the token (ERC721)
     * @param _owner_ The owner of the token (Ownable)
     * @param _pricePerSecond_ The price of the subscription in wei per second
     * @param _minDuration_ The minimum duration of the subscription in seconds
     * @param _maxDuration_ The maximum duration of the subscription in seconds
     * @param _fundsRecipient_ The address that receives funds
     */
    constructor(
        string memory _name_, 
        string memory _symbol_,
        address _owner_,
        uint256 _pricePerSecond_,
        uint256 _minDuration_,
        uint256 _maxDuration_,
        address _fundsRecipient_
    ) ERC721(_name_, _symbol_) Ownable(_owner_) {
        setDurationBounds(_minDuration_, _maxDuration_);
        setPrice(_pricePerSecond_);
        setFundsRecipient(_fundsRecipient_);
    }
    
    //========== Public Functions ==========

    /**
     * @inheritdoc IERC721S
     */
    function setDurationBounds(uint256 newMinDuration, uint256 newMaxDuration) public onlyOwner {
        if (newMinDuration > newMaxDuration) revert InvalidDuration(newMinDuration);
        minDuration = newMinDuration;
        maxDuration = newMaxDuration;
        emit DurationBoundsUpdated(newMinDuration, newMaxDuration);
    }

    /**
     * @inheritdoc IERC721S
     */
    function setPrice(uint256 newPricePerSecond) public onlyOwner {
        pricePerSecond = newPricePerSecond;
        emit SubscriptionPriceUpdated(newPricePerSecond);
    }

    /**
     * @inheritdoc IERC721S
     */
    function setFundsRecipient(address newFundsRecipient) public onlyOwner {
        if (newFundsRecipient == address(0x0)) revert InvalidAddress("newFundsRecipient", newFundsRecipient);
        fundsRecipient = newFundsRecipient;
        emit FundsRecipientUpdated(newFundsRecipient);
    }
    
    /**
     * @inheritdoc IERC721S
     */
    function subscribe(
        address subscriptionOwner,
        uint256 durationInSeconds,
        uint256 totalCostInWei
    ) public payable nonReentrant returns (uint256 tokenId, uint256 expiration) {
        // Validate
        uint256 calculatedCost = getSubscriptionCost(durationInSeconds);
        if (calculatedCost != totalCostInWei) revert CostMismatch(calculatedCost, totalCostInWei);
        if (msg.value != calculatedCost) revert InsufficientPayment(calculatedCost, msg.value);
        if (durationInSeconds < minDuration || durationInSeconds > maxDuration) {
            revert InvalidDuration(durationInSeconds);
        }

        // Send payment to the funds recipient
        // If the funds recipient is self then keep the funds
        if (fundsRecipient != address(this)) {
            (bool success, ) = payable(fundsRecipient).call{value: calculatedCost}("");
            if (!success) revert NativeTransferFailed(fundsRecipient, calculatedCost);
        }
        emit PaymentReceived(subscriptionOwner, msg.sender, calculatedCost);

        // Derive token id
        tokenId = deriveTokenId(subscriptionOwner);

        // If the owner has an active subscription, extend the expiration
        // Otherwise, start a new subscription
        if (isSubscriptionActive(tokenId)) {
            // Calculate expiration from current expiration
            expiration = expirations[tokenId] + durationInSeconds;
            emit SubscriptionExtended(subscriptionOwner, tokenId, expiration);
        } else {
            // Calculate expiration from current timestamp
            expiration = block.timestamp + durationInSeconds;
            emit SubscriptionStarted(subscriptionOwner, tokenId, block.timestamp, expiration);
        }

        // Mint a new token if the owner has no subscription token
        if (balanceOf(subscriptionOwner) == 0 && _ownerOf(tokenId) == address(0x0)) {
            // Safe mint so contracts are aware
            _safeMint(subscriptionOwner, tokenId);
        }

        // Set expiration
        expirations[tokenId] = expiration;

        // Return token id and expiration
        return (tokenId, expiration);
    }
    
    /**
     * @inheritdoc IERC721S
     */
    function withdraw() external onlyOwner {
        // Transfer full native balance to the contract owner
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        if (!success) revert NativeTransferFailed(owner(), address(this).balance);
    }

    //========== View/Pure Functions ==========

    /**
     * @inheritdoc IERC721S
     */
    function getSubscriptionCost(uint256 durationInSeconds) public view returns (uint256) {
        return durationInSeconds * pricePerSecond;
    }

    /**
     * @inheritdoc IERC721S
     */
    function deriveTokenId(address account) public pure returns (uint256) {
        return uint256(uint160(account));
    }

    /**
     * @inheritdoc IERC721S
     */
    function hasActiveSubscription(address account) public view returns (bool) {
        if (balanceOf(account) == 0 && _ownerOf(deriveTokenId(account)) == address(0x0)) return false; //No subscription token
        if (!isSubscriptionActive(deriveTokenId(account))) return false; //Subscription expired
        return true;
    }

    /**
     * @inheritdoc IERC721S
     */
    function isSubscriptionActive(uint256 tokenId) public view returns (bool) {
        return expirations[tokenId] > block.timestamp;
    }

    //========== Override Functions ==========

    /**
     * @dev Override _update to prevent transfers except by the contract owner
     * @param to The address to transfer to
     * @param tokenId The token ID to transfer
     * @param auth The address initiating the transfer
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        // Only allow mints (from zero address)
        address from = _ownerOf(tokenId);
        if (from != address(0x0)) {
            revert TokenNonTransferable();
        }
        return super._update(to, tokenId, auth);
    }
}
