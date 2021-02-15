/// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/// @dev interface for sushi bar (`xSUSHI`) txs
interface ISushiBar { 
   function enter(uint256 _amount) external;
   function leave(uint256 _share) external;
}
