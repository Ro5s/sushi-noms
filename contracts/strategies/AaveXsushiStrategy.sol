// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "https://github.com/sushiswap/bentobox/blob/master/contracts/interfaces/IStrategy.sol";
import "https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringOwnable.sol";
import "https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/libraries/BoringMath.sol";
import "https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/libraries/BoringERC20.sol";

// solhint-disable avoid-low-level-calls
// solhint-disable not-rely-on-time
// solhint-disable no-empty-blocks
// solhint-disable avoid-tx-origin

library DataTypes {
    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 variableBorrowIndex;
        uint128 currentLiquidityRate;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint8 id;
    }
    
    struct ReserveConfigurationMap {
        uint256 data;
    }
}

interface IaToken {
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
    
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

contract AaveXsushiStrategy is IStrategy, BoringOwnable {
    using BoringMath for uint256;
    using BoringERC20 for IERC20;
    using BoringERC20 for IaToken;
    
    address public immutable aave;
    address public immutable bentobox;
    address public immutable xSushi;
    address public immutable aXsushi;
    bool public exited;

    constructor(
        address aave_,
        address bentobox_,
        address xSushi_
    ) public {
        aave = aave_;
        bentobox = bentobox_;
        xSushi = xSushi_;
        IERC20(xSushi_).approve(aave_, type(uint256).max);
        aXsushi = IaToken(aave_).getReserveData(xSushi_).aTokenAddress;
    }

    modifier onlyBentobox {
        // @dev Only the bentobox can call harvest on this strategy.
        require(msg.sender == bentobox, "AaveStrategy: only bento");
        require(!exited, "AaveStrategy: exited");
        _;
    }

    /// @notice Send the assets to the Strategy and call skim to invest them.
    /// @inheritdoc IStrategy
    function skim(uint256 amount) external override onlyBentobox {
        IaToken(aave).deposit(xSushi, amount, address(this), 0);
    }

    /// @notice Harvest any profits made converted to the asset and pass them to the caller.
    /// @inheritdoc IStrategy
    function harvest(uint256 balance, address sender) external override onlyBentobox returns (int256 amountAdded) {
        // @dev To prevent anyone from using flash loans to 'steal' part of the profits, only EOA is allowed to call harvest.
        require(sender == tx.origin, "AaveStrategy: EOA only");
        // @dev Get the amount of tokens that the aTokens currently represent.
        uint256 tokenBalance = IERC20(aXsushi).safeBalanceOf(address(this));
        // @dev Convert enough aToken to take out the profit.
        // If the amount is negative due to rounding (near impossible), just revert (should be positive soon enough).
        IaToken(aave).withdraw(xSushi, tokenBalance.sub(balance), address(this));
        uint256 amountAdded_ = IERC20(xSushi).safeBalanceOf(address(this));
        // @dev Transfer the profit to the bentobox, the amountAdded at this point matches the amount transferred.
        IERC20(xSushi).safeTransfer(bentobox, amountAdded_);
        return int256(amountAdded_);
    }

    /// @notice Withdraw assets.
    /// @inheritdoc IStrategy
    function withdraw(uint256 amount) external override onlyBentobox returns (uint256 actualAmount) {
        // @dev Convert enough aToken to take out 'amount' tokens.
        IaToken(aave).withdraw(xSushi, amount, address(this));
        // @dev Make sure we send and report the exact same amount of tokens by using balanceOf.
        actualAmount = IERC20(xSushi).safeBalanceOf(address(this));
        IERC20(xSushi).safeTransfer(bentobox, actualAmount);
    }

    /// @notice Withdraw all assets in the safest way possible - this shouldn't fail.
    /// @inheritdoc IStrategy
    function exit(uint256 balance) external override onlyBentobox returns (int256 amountAdded) {
        // @dev Get the amount of tokens that the aTokens currently represent.
        uint256 tokenBalance = IERC20(aXsushi).safeBalanceOf(address(this));
        // @dev Get the actual token balance of the cToken contract.
        uint256 available = IERC20(xSushi).safeBalanceOf(aXsushi);
        // @dev Check that the aToken contract has enough balance to pay out in full.
        if (tokenBalance <= available) {
            // @dev If there are more tokens available than our full position, take all based on aToken balance (continue if unsuccessful).
            try IaToken(aave).withdraw(xSushi, tokenBalance, address(this)) {} catch {}
        } else {
            // @dev Otherwise redeem all available and take a loss on the missing amount (continue if unsuccessful).
            try IaToken(aave).withdraw(xSushi, available, address(this)) {} catch {}
        }
        // @dev Check balance of token on the contract.
        uint256 amount = IERC20(xSushi).safeBalanceOf(address(this));
        // @dev Calculate tokens added (or lost).
        amountAdded = int256(amount) - int256(balance);
        // @dev Transfer all tokens to bentobox.
        IERC20(xSushi).safeTransfer(bentobox, amount);
        // @dev Flag as exited, allowing the owner to manually deal with any amounts available later.
        exited = true;
    }

    function afterExit(
        address to,
        uint256 value,
        bytes memory data
    ) public onlyOwner returns (bool success) {
        // @dev After exited, the owner can perform ANY call. This is to rescue any funds that didn't get released during exit or
        // got earned afterwards due to vesting or airdrops, etc.
        require(exited, "AaveStrategy: Not exited");
        (success, ) = to.call{value: value}(data);
    }
}
