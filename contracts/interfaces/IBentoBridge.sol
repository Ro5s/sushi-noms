/// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/// @notice Interface for BENTO deposit and withdraw.
interface IBentoBridge {
    function balanceOf(IERC20, address) external view returns (uint256);

    function registerProtocol() external;

    function deposit( 
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    function withdraw(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}
