/// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/// @notice Interface for COMPOUND deposit and withdraw.
interface ICompoundBridge {
    function underlying() external view returns (address);
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
}
