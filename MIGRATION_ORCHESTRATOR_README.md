# Farm Migration Orchestrator

This contract automates the process of migrating from one farm to another through a three-step process:

1. **Withdraw from SimpleFarmA** (VERSE tokens)
2. **Swap VERSE to tBTC** and acquire LP tokens from Balancer V3 pool
3. **Stake LP tokens in SimpleFarmB**

## Overview

The `FarmMigrationOrchestrator` contract streamlines the migration process by handling all the complex interactions with Balancer V3 pools and farm contracts in a single transaction.

## Contract Architecture

### Key Components

- **SimpleFarmA**: Source farm containing VERSE tokens
- **SimpleFarmB**: Destination farm for LP tokens
- **Balancer V3 Pool**: Pool for VERSE/tBTC trading and LP token acquisition
- **Balancer Vault**: Main contract for swaps and liquidity operations

### Workflow

1. User withdraws from SimpleFarmA (must be done separately)
2. User transfers VERSE tokens to the orchestrator contract
3. Contract swaps specified amount of VERSE for tBTC
4. Contract adds liquidity to Balancer pool to acquire LP tokens
5. Contract stakes LP tokens in SimpleFarmB
6. Contract returns remaining VERSE tokens to user

## Usage Instructions

### Prerequisites

1. **Environment Setup**
   ```bash
   # Set environment variables
   export PRIVATE_KEY="your_private_key"
   export VERSE_TOKEN="0x..."
   export TBTC_TOKEN="0x..."
   export LP_TOKEN="0x..."
   export SIMPLE_FARM_A="0x..."
   export SIMPLE_FARM_B="0x..."
   ```

2. **Deploy the Contract**
   ```bash
   forge script contracts/Scripts/DeployMigrationOrchestrator.s.sol --rpc-url $RPC_URL --broadcast
   ```

### Step-by-Step Migration Process

#### Step 1: Prepare for Migration
```solidity
// Approve the orchestrator contract to spend your VERSE tokens
orchestrator.prepareForMigration(amount);
```

#### Step 2: Withdraw from SimpleFarmA
```solidity
// Withdraw your VERSE tokens from the source farm
simpleFarmA.farmWithdraw(amount);
```

#### Step 3: Transfer VERSE to Orchestrator
```solidity
// Transfer VERSE tokens to the orchestrator contract
verseToken.transfer(address(orchestrator), amount);
```

#### Step 4: Execute Migration
```solidity
// Execute the complete migration process
orchestrator.executeMigration(
    verseAmount,    // Total VERSE amount available
    verseToSwap,    // Amount to swap for tBTC
    minTbtcOut,     // Minimum tBTC expected from swap
    minLpOut        // Minimum LP tokens expected
);
```

### Example Usage

```javascript
// Example using ethers.js
const orchestrator = await FarmMigrationOrchestrator.attach(orchestratorAddress);

// Step 1: Approve spending
await orchestrator.prepareForMigration(ethers.utils.parseEther("1000"));

// Step 2: Withdraw from farm (user must do this manually)
// await simpleFarmA.farmWithdraw(ethers.utils.parseEther("1000"));

// Step 3: Transfer VERSE to orchestrator
await verseToken.transfer(orchestratorAddress, ethers.utils.parseEther("1000"));

// Step 4: Execute migration
await orchestrator.executeMigration(
    ethers.utils.parseEther("1000"),  // Total VERSE
    ethers.utils.parseEther("500"),   // Swap 500 VERSE for tBTC
    ethers.utils.parseEther("450"),   // Expect at least 450 tBTC
    ethers.utils.parseEther("900")    // Expect at least 900 LP tokens
);
```

## Contract Functions

### Main Functions

#### `executeMigration(uint256 _verseAmount, uint256 _verseToSwap, uint256 _minTbtcOut, uint256 _minLpOut)`
Executes the complete migration process.

**Parameters:**
- `_verseAmount`: Total VERSE tokens available for migration
- `_verseToSwap`: Amount of VERSE to swap for tBTC
- `_minTbtcOut`: Minimum tBTC tokens expected from swap
- `_minLpOut`: Minimum LP tokens expected from liquidity addition

#### `prepareForMigration(uint256 _amount)`
Helper function to approve the contract to spend VERSE tokens.

### View Functions

#### `estimateMigration(uint256 _verseAmount, uint256 _verseToSwap)`
Returns estimated migration results (simplified estimation).

### Admin Functions

#### `proposeNewOwner(address _newOwner)`
Proposes a new owner (owner only).

#### `claimOwnership()`
Claims ownership after being proposed.

#### `recoverToken(IERC20 _token, uint256 _amount)`
Emergency function to recover stuck tokens (owner only).

## Security Considerations

1. **Approvals**: Users must explicitly approve the contract to spend their tokens
2. **Slippage Protection**: Use appropriate `_minTbtcOut` and `_minLpOut` values
3. **Ownership**: Contract has owner controls for emergency functions
4. **Reentrancy**: Contract uses SafeERC20 for all token operations

## Balancer V3 Integration

The contract integrates with Balancer V3 using:
- **Balancer Vault**: For token swaps
- **Balancer Router**: For liquidity addition
- **Pool ID**: Identifies the specific VERSE/tBTC pool

### Pool Configuration
- **Pool Address**: `0x02345DA85777B7E5ED740E0Df3BBcA93EF03fe9f`
- **Pool ID**: `0x02345DA85777B7E5ED740E0Df3BBcA93EF03fe9f000200000000000000000000`
- **Tokens**: VERSE and tBTC

## Gas Optimization

The contract is optimized for gas efficiency by:
- Using `immutable` variables where possible
- Minimizing storage operations
- Batching operations in single transactions

## Testing

To test the contract:

```bash
# Run all orchestrator tests (including mainnet fork tests)
bun run foundry-test-orchestrator

# Run only executor contract tests
bun run foundry-test-executor

# Run mainnet fork tests only
bun run foundry-test-orchestrator-fork

# Show all available orchestrator commands
bun run show-orchestrator-commands

# Manual forge commands (alternative)
forge test --match-contract FarmMigrationOrchestrator --fork-url https://mainnet.infura.io/v3/YOUR_API_KEY
forge test --match-contract FarmMigrationOrchestratorV3ExecutorTest
```

## Deployment

### Mainnet Deployment
```bash
# Deploy to mainnet
bun run deploy-migration-executor

# Deploy to polygon
bun run deploy-migration-executor-polygon

# Manual deployment (alternative)
forge script contracts/Scripts/DeployMigrationOrchestrator.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

### Environment Variables Required
Make sure to set these environment variables before deployment:
```bash
export PRIVATE_KEY="your_private_key"
export SIMPLE_FARM_A="0x..."
export SIMPLE_FARM_B="0x..."
export VERSE_TOKEN="0x..."
export TBTC_TOKEN="0x..."
```

### Verification
After deployment, verify the contract on Etherscan with the constructor arguments.

## Troubleshooting

### Common Issues

1. **Insufficient Balance**: Ensure the contract has enough VERSE tokens before calling `executeMigration`
2. **Slippage**: If swap fails, increase `_minTbtcOut` or `_minLpOut` values
3. **Approval**: Make sure to call `prepareForMigration` before executing migration

### Emergency Procedures

If tokens get stuck in the contract:
1. Owner can call `recoverToken()` to extract tokens
2. Contact the contract owner for assistance

## License

This contract is licensed under the BCOM license.
