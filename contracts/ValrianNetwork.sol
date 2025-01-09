// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ValyrianNetwork ($VLNT) - A decentralized token contract with burn and reward mechanics
/// @notice This ERC20 token contract implements a fixed initial supply of 7 billion tokens,
/// @author Koleen BP: https://x.com/kbpsystem & https://x.com/valyriannet
/// an ETH-to-token exchange mechanism, periodic token burning, and rewards for the user initiating the burn.
/// The burning process ensures that 7,777 tokens from the total supply is burned everyday until 77% of the initial supply remains.
contract ValyrianNetwork is ERC20, Ownable, ReentrancyGuard {
    // Constants
    uint256 public constant INITIAL_SUPPLY = 7_000_000_000 * 10 ** 18;
    uint256 public constant ETH_TO_TOKEN_RATE = 77000 * 10 ** 18;
    uint256 public constant TARGET_SUPPLY = (INITIAL_SUPPLY * 77) / 100;
    uint256 public constant BURN_PERCENTAGE_SCALED = 7777 * 10 ** 18;
    uint256 public constant BURN_INTERVAL = 1 days;
    uint256 public constant REWARDS_GIVEN_TO_BURNER = 816 * 10 ** 18;

    uint256 public lastBurnTime;
    address public lastBurner;

    event EthReceived(address indexed _sender, uint256 _ethAmountSent);
    event TokenBurned(uint256 _amount);
    event LastBurner(address _burnerAddress);
    event EthWithdrawal(address indexed _vlntOwner, uint256 _amount);

    /// @notice Constructor initializes the token contract by minting the entire initial supply to the contract.
    /// @dev Sets the burn timestamp to the deployment time.
    constructor() ERC20("Valyrian Network", "VLNT") Ownable(msg.sender) {
        _mint(address(this), INITIAL_SUPPLY);
        lastBurnTime = block.timestamp;
    }

    /// @notice Allows users to purchase tokens by sending ETH to the contract.
    /// @dev Converts ETH sent to the contract into tokens at a fixed rate of 77000 tokens per ETH.
    /// Ensures sufficient token balance in the contract before transferring tokens to the buyer.
    receive() external payable nonReentrant {
        require(msg.value > 0, "Must send ETH to receive tokens");

        uint256 tokensToTransfer;
        unchecked {
            tokensToTransfer = (msg.value * ETH_TO_TOKEN_RATE) / 1 ether;
        }

        require(
            balanceOf(address(this)) >= tokensToTransfer,
            "Not enough tokens left in contract"
        );
        _transfer(address(this), msg.sender, tokensToTransfer);
        emit EthReceived(msg.sender, msg.value);
    }

    /// @notice Triggers the periodic burning of tokens and rewards the caller with additional tokens.
    /// @dev Burns a fixed amount of tokens everyday, rewarding the caller with a predefined amount of tokens.
    /// Stops burning when the total supply reaches the target supply (77% of the initial supply).
    function burn() external nonReentrant {
        require(
            block.timestamp >= lastBurnTime + BURN_INTERVAL,
            "Burn not yet allowed"
        );

        uint256 supply = totalSupply();
        require(totalSupply() > TARGET_SUPPLY, "Burn target already reached");

        uint256 burnAmount = BURN_PERCENTAGE_SCALED;

        unchecked {
            if (supply - burnAmount < TARGET_SUPPLY) {
                burnAmount = supply - TARGET_SUPPLY;
            }
        }

        _burn(address(this), burnAmount);

        // Transferring VLNT tokens to msg.sender as a reward
        // for triggering the burn
        require(
            balanceOf(address(this)) > REWARDS_GIVEN_TO_BURNER,
            "Budget for rewards has been maxed out"
        );
        _transfer(address(this), msg.sender, REWARDS_GIVEN_TO_BURNER);

        lastBurnTime = block.timestamp;
        lastBurner = msg.sender;

        emit LastBurner(msg.sender);
        emit TokenBurned(burnAmount);
    }

    /// @notice Allows the contract owner to withdraw all ETH held by the contract.
    /// @dev Only callable by the contract owner.
    function withdrawETH() external onlyOwner {
        uint256 currentBalance = address(this).balance;

        payable(owner()).transfer(currentBalance);
        emit EthWithdrawal(msg.sender, currentBalance);
    }
}
