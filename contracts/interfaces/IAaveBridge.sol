/// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/// @notice Interface for AAVE deposit and withdraw.
interface IAaveBridge {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function deposit( 
        address asset, 
        uint256 amount, 
        address onBehalfOf, 
        uint16 referralCode
    ) external;

    function withdraw( 
        address token, 
        uint256 amount, 
        address destination
    ) external;
}
