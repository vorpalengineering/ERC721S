# ERC721S - Subscription Token Standard

ERC721S is a specialized ERC721 token standard designed for managing subscription-based services. It provides a secure and efficient way to handle subscription tokens that are non-transferable and tied to specific user addresses.

## Project Summary

ERC721S extends the ERC721 standard to create a subscription token system where:
- Each user can have one subscription token
- Token IDs are derived from user addresses
- Subscriptions have configurable durations and pricing
- Tokens are non-transferable
- Subscriptions can be extended while active

## Features

- **Non-transferable Tokens**: Subscription tokens cannot be transferred between addresses
- **Address-based Token IDs**: Each user's token ID is derived from their address
- **Configurable Duration**: Subscriptions can be set between 1 day and 365 days
- **Flexible Pricing**: Price per second can be adjusted by the contract owner
- **Subscription Extension**: Active subscriptions can be extended
- **Secure Payment Handling**: Built-in payment processing with recipient address
- **Reentrancy Protection**: Implements OpenZeppelin's ReentrancyGuard
- **Ownership Management**: Uses OpenZeppelin's Ownable2Step for secure ownership transfers

## Project Setup

### Prerequisites

- Foundry (for development and testing)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/vorpalengineering/ERC721S.git
cd ERC721S
```

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

## Running Tests

Run the test suite using Foundry:

```bash
forge test
```

For verbose output:

```bash
forge test -vv
```

## Interface Breakdown

### Core Functions

- `subscribe(address subscriptionOwner, uint256 durationInSeconds, uint256 totalCostInWei)`: Creates or extends a subscription
- `setPrice(uint256 newPricePerSecond)`: Updates the subscription price (owner only)
- `setFundsRecipient(address newFundsRecipient)`: Sets the payment recipient address (owner only)
- `withdraw()`: Withdraws contract balance to owner (owner only)

### View Functions

- `getSubscriptionCost(uint256 durationInSeconds)`: Calculates subscription cost based on given duration
- `deriveTokenId(address account)`: Derives token ID from address
- `hasActiveSubscription(address account)`: Checks if an address has an active subscription
- `isSubscriptionActive(uint256 tokenId)`: Checks if a specific token is active

### State Variables

- `MIN_SUBSCRIPTION_DURATION`: Minimum subscription period (e.g. 1 day)
- `MAX_SUBSCRIPTION_DURATION`: Maximum subscription period (e.g. 365 days)
- `pricePerSecond`: Cost per second of subscription
- `fundsRecipient`: Address receiving subscription payments

## Example Usage

### Deploying the Contract

```solidity
// Deploy with the following parameters:
string memory name = "MySubscription";
string memory symbol = "SUB";
address owner = msg.sender;
uint256 pricePerSecond = 0.0001 ether / 1 days; // 0.1 ETH per day
uint256 minDuration = 1 days;
uint256 maxDuration = 365 days;
address fundsRecipient = msg.sender;

ERC721S subscription = new ERC721S(
    name,
    symbol,
    owner,
    pricePerSecond,
    minDuration,
    maxDuration,
    fundsRecipient
);
```

### Creating a Subscription

```solidity
// Calculate cost for 30 days
uint256 duration = 30 days;
uint256 cost = subscription.getSubscriptionCost(duration);

// Create subscription
(uint256 tokenId, uint256 expiration) = subscription.subscribe{value: cost}(
    msg.sender,
    duration,
    cost
);
```

### Checking Subscription Status

```solidity
// Check if an address has an active subscription
bool isActive = subscription.hasActiveSubscription(userAddress);

// Get subscription expiration
uint256 tokenId = subscription.deriveTokenId(userAddress);
uint256 expiration = subscription.expirations(tokenId);
```

## Security Considerations

- The contract uses OpenZeppelin's ReentrancyGuard to prevent reentrancy attacks
- Ownership transfers use a two-step process (Ownable2Step)
