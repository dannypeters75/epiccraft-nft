# EpicCraft Gaming NFT Contract

## Overview

EpicCraft Gaming NFT Contract is a comprehensive blockchain solution for managing in-game digital assets, player progression, and marketplace transactions in a decentralized gaming ecosystem. Built on the Clarity smart contract language, this contract provides a robust foundation for blockchain-powered gaming applications.

## Features

### NFT Asset Management
- Create individual and batch NFTs with customizable metadata
- Secure ownership tracking with principal addresses
- Configurable transferability settings
- Comprehensive NFT lifecycle management

### Decentralized Marketplace
- List gaming assets for sale with custom pricing
- Purchase assets directly through secure transactions
- Cancel listings with proper authorization
- Automatic marketplace management and record-keeping

### Player Progression System
- Track hero experience and level data on-chain
- Enforce maximum progression limits
- Associate progression with player wallet addresses
- Persistent cross-game character development

### Administrative Controls
- Contract administrator privileges for NFT creation
- System-wide parameter limits for safety
- Comprehensive input validation and error handling

## Technical Specifications

- **Language**: Clarity
- **Compatible with**: Stacks blockchain
- **Storage Maps**: 4 distinct data stores for game assets, pricing, progression and listings
- **System Limits**:
  - Maximum hero level: 100
  - Maximum hero experience: 10,000
  - Maximum NFT metadata size: 256 characters
  - Maximum batch transaction size: 10 items

## Function Documentation

### NFT Creation

#### `create-nft`
Create a single gaming NFT asset.

Parameters:
- `metadata-uri`: String (max 256 chars) - URI pointing to the asset metadata
- `transferable`: Boolean - Whether the NFT can be transferred between users

Returns:
- `(ok uint)` - The ID of the newly created NFT

#### `batch-create-nfts`
Create multiple NFTs in a single transaction.

Parameters:
- `metadata-uri-batch`: List of strings - URIs for each NFT's metadata
- `transferability-flags`: List of booleans - Transfer permission for each NFT

Returns:
- `(ok (list (response uint int)))` - List of created NFT IDs or errors

### Asset Transfer

#### `transfer-nft`
Transfer ownership of an NFT to another address.

Parameters:
- `nft-id`: Integer - The ID of the NFT to transfer
- `recipient`: Principal - The address to receive the NFT

Returns:
- `(ok true)` or error

#### `batch-transfer-nfts`
Transfer multiple NFTs in a single transaction.

Parameters:
- `nft-id-batch`: List of integers - The NFT IDs to transfer
- `recipient-addresses`: List of principals - Recipient addresses

Returns:
- `(ok (list (response bool int)))` - Results of each transfer operation

### Marketplace Functions

#### `create-market-listing`
List an NFT for sale on the marketplace.

Parameters:
- `nft-id`: Integer - The ID of the NFT to list
- `asking-price`: Integer - The price in STX tokens

Returns:
- `(ok true)` or error

#### `purchase-listed-nft`
Buy an NFT listed on the marketplace.

Parameters:
- `nft-id`: Integer - The ID of the NFT to purchase

Returns:
- `(ok true)` or error

#### `cancel-market-listing`
Remove an NFT from the marketplace.

Parameters:
- `nft-id`: Integer - The ID of the listed NFT to delist

Returns:
- `(ok true)` or error

### Player Progression

#### `update-hero-stats`
Update a player's hero stats.

Parameters:
- `new-experience`: Integer - Updated experience points
- `new-level`: Integer - Updated hero level

Returns:
- `(ok true)` or error

### Read-Only Functions

#### `get-nft-details`
Retrieve details about a specific NFT.

Parameters:
- `nft-id`: Integer - The ID of the NFT

Returns:
- NFT data or `none`

#### `get-market-listing-info`
Get information about a marketplace listing.

Parameters:
- `nft-id`: Integer - The ID of the listed NFT

Returns:
- Listing data or `none`

#### `get-hero-stats`
Get a player's hero progression data.

Parameters:
- `player-address`: Principal - The player's address

Returns:
- Hero stats or `none`

#### `get-total-nfts-count`
Get the total number of NFTs minted.

Parameters:
- None

Returns:
- `uint` - Total NFT count

## Error Codes

- `ERR-ADMIN-ONLY` (u100): Function can only be called by contract administrator
- `ERR-RESOURCE-NOT-FOUND` (u101): The requested NFT or resource doesn't exist
- `ERR-UNAUTHORIZED-ACCESS` (u102): Caller doesn't have permission for this operation
- `ERR-INVALID-PARAMETERS` (u103): Input parameters are invalid or out of bounds
- `ERR-INVALID-MARKET-PRICE` (u104): Marketplace price is invalid (must be > 0)

## Integration Guide

### Minting NFTs
```clarity
;; Create an individual NFT
(contract-call? .epiccraft-nft create-nft "https://metadata.example.com/item/123" true)

;; Create multiple NFTs in batch
(contract-call? .epiccraft-nft batch-create-nfts 
  (list "https://metadata.example.com/item/124" "https://metadata.example.com/item/125")
  (list true true))
```

### Marketplace Integration
```clarity
;; List an NFT for sale
(contract-call? .epiccraft-nft create-market-listing u1 u100000000) ;; List NFT #1 for 100 STX

;; Purchase an NFT
(contract-call? .epiccraft-nft purchase-listed-nft u1) ;; Buy NFT #1
```

### Player System Integration
```clarity
;; Update hero stats after gameplay
(contract-call? .epiccraft-nft update-hero-stats u500 u7) ;; Set 500 XP, level 7
```

## Security Considerations

- All asset transfers and marketplace operations require proper authorization
- Input validation occurs throughout all functions
- Batch operations are limited to prevent gas-limit issues
- Self-transfers are explicitly prevented
- Only the contract administrator can mint new NFTs

## Deployment Recommendations

1. Deploy via a multisig wallet for administrative functions
2. Set appropriate initial constants based on game economy design
3. Test thoroughly on testnet before mainnet deployment
4. Consider implementing additional hooks for game-specific mechanics