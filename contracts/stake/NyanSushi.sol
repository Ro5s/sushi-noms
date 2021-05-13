// SPDX-License-Identifier: UNLICENSED
// NekoSushi....🐈_🍣_🍱

pragma solidity 0.8.4;

// File @boringcrypto/boring-solidity/contracts/Domain.sol@v1.2.0
// License-Identifier: MIT
// Based on code and smartness by Ross Campbell and Keno
// Uses immutable to store the domain separator to reduce gas usage
// If the chain id changes due to a fork, the forked chain will calculate on the fly.

contract Domain {
    bytes32 private constant DOMAIN_SEPARATOR_SIGNATURE_HASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    // See https://eips.ethereum.org/EIPS/eip-191
    string private constant EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA = "\x19\x01";

    // solhint-disable var-name-mixedcase
    bytes32 private immutable _DOMAIN_SEPARATOR;
    uint256 private immutable DOMAIN_SEPARATOR_CHAIN_ID;

    /// @dev Calculate the DOMAIN_SEPARATOR
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_SIGNATURE_HASH, chainId, address(this)));
    }

    constructor() {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(DOMAIN_SEPARATOR_CHAIN_ID = chainId);
    }

    /// @dev Return the DOMAIN_SEPARATOR
    // It's named internal to allow making it public from the contract that uses it by creating a simple view function
    // with the desired public name, such as DOMAIN_SEPARATOR or domainSeparator.
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId == DOMAIN_SEPARATOR_CHAIN_ID ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(chainId);
    }

    function _getDigest(bytes32 dataHash) internal view returns (bytes32 digest) {
        digest = keccak256(abi.encodePacked(EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA, DOMAIN_SEPARATOR(), dataHash));
    }
}

// File @boringcrypto/boring-solidity/contracts/ERC20.sol@v1.2.0
// License-Identifier: MIT

/// @dev Data part taken out for building of contracts that receive delegate calls.
contract ERC20Data {
    /// @notice owner > balance mapping.
    mapping(address => uint256) public balanceOf;
    /// @notice owner > spender > allowance mapping.
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice owner > nonce mapping. Used in `permit`.
    mapping(address => uint256) public nonces;
}

contract ERC20 is ERC20Data, Domain {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @notice Transfers `amount` tokens from `msg.sender` to `to`.
    /// @param to The address to move the tokens.
    /// @param amount of the tokens to move.
    /// @return (bool) Returns True if succeeded.
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount; 
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Transfers `amount` tokens from `from` to `to`. Caller needs approval for `from`.
    /// @param from Address to draw tokens from.
    /// @param to The address to move the tokens.
    /// @param amount The token amount to move.
    /// @return (bool) Returns True if succeeded.
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 spenderAllowance = allowance[from][msg.sender];
        // If allowance is infinite, don't decrease it to save on gas (breaks with EIP-20).
        if (spenderAllowance != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount; 
        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice Approves `amount` from sender to be spend by `spender`.
    /// @param spender Address of the party that can draw from msg.sender's account.
    /// @param amount The maximum collective amount that `spender` can draw.
    /// @return (bool) Returns True if approved.
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant PERMIT_SIGNATURE_HASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice Approves `value` from `owner_` to be spend by `spender`.
    /// @param owner Address of the owner.
    /// @param spender The address of the spender that gets approved to draw from `owner_`.
    /// @param amount The maximum collective amount that `spender` can draw.
    /// @param deadline This permit must be redeemed before this deadline (UTC timestamp in seconds).
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(owner != address(0), "ERC20: Owner cannot be 0");
        require(block.timestamp < deadline, "ERC20: Expired");
        require(
            ecrecover(_getDigest(keccak256(abi.encode(PERMIT_SIGNATURE_HASH, owner, spender, amount, nonces[owner]++, deadline))), v, r, s) ==
                owner,
            "ERC20: Invalid Signature"
        );
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

contract BaseBoringBatchable {
    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail itself.
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /// @notice Allows batched call to self (this contract).
    /// @param calls An array of inputs for each call.
    /// @param revertOnFail If True then reverts after a failed call and stops doing further calls.
    // F1: External is ok here because this is the batch function, adding it to a batch makes no sense
    // F2: Calls in the batch may be payable, delegatecall operates in the same context, so each call in the batch has access to msg.value
    // C3: The length of the loop is fully under user control, so can't be exploited
    // C7: Delegatecall is only used on the same contract, so it's safe
    function batch(bytes[] calldata calls, bool revertOnFail) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success && revertOnFail) {
                revert(_getRevertMsg(result));
            }
        }
    }
}

/// @notice Interface for depositing into and withdrawing from BentoBox vault.
interface IERC20{} interface IBentoBoxBasic {
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

/// @notice Interface for depositing into and withdrawing from SushiBar.
interface ISushiBar { 
    function balanceOf(address account) external view returns (uint256);
    function enter(uint256 amount) external;
    function leave(uint256 share) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/// @notice Interface for SushiSwap.
interface ISushiSwap {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

/// @notice Interface for Ether wrapper contract v9 deposits.
interface IWETH9 {
    function deposit() external payable;
    function transfer(address dst, uint wad) external returns (bool);
}

contract NekoSushi is ERC20, BaseBoringBatchable {
    IBentoBoxBasic constant private bentoBox = IBentoBoxBasic(0xF5BCE5077908a1b7370B9ae04AdC565EBd643966); // BENTO vault contract
    ISushiBar constant private sushiToken = ISushiBar(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2); // SUSHI token contract
    address constant private sushiBar = 0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272; // xSUSHI staking contract for SUSHI
    ISushiSwap constant private sushiSwapSushiETHpair = ISushiSwap(0x795065dCc9f64b5614C407a6EFDC400DA6221FB0); // SUSHI/ETH pair on SushiSwap
    IWETH9 constant private wETH9 = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // ETH wrapper contract v9
    
    string constant public name = "Neko SUSHI";
    string constant public symbol = "NEKO";
    uint8 constant public decimals = 18;
    uint256 constant private multiplier = 1000; // 1 xSUSHI = 1000 NYAN
    uint256 public totalSupply;
    
    constructor() {
        sushiToken.approve(sushiBar, type(uint256).max); // max approve `sushiBar` spender to pull SUSHI from this contract
        ISushiBar(sushiBar).approve(address(bentoBox), type(uint256).max); // max approve `bentoBox` spender to pull xSUSHI from this contract
    }
    
    /// @dev Enter NyanSushi. Pay some xSUSHI. Get NYAN.
    function nyan(address to, uint256 amount) external {
        ISushiBar(sushiBar).transferFrom(msg.sender, address(this), amount);
        (, uint256 shares) = bentoBox.deposit(IERC20(sushiBar), address(this), address(this), amount, 0); // stake resulting xSUSHI into BENTO
        nyanMint(to, shares * multiplier);
    }

    /// @dev Leave NyanSushi. Claim back your xSUSHI.
    function unNyan(address to, uint256 amount) external {
        nyanBurn(amount);
        (uint256 amountOut, ) = bentoBox.withdraw(IERC20(sushiBar), address(this), address(this), 0, amount / multiplier); // withdraw adjusted xSUSHI share amount from BENTO
        ISushiBar(sushiBar).transfer(to, amountOut); // transfer resulting xSUSHI to `to`
    }
    
    /// **** SUSHI NYAN ****
    /// @dev Enter NyanSushi. Pay some SUSHI. Get NYAN.
    function nyanSUSHI(address to, uint256 amount) external {
        sushiToken.transferFrom(msg.sender, address(this), amount);
        ISushiBar(sushiBar).enter(amount); // stake deposited SUSHI into `sushiBar` xSUSHI
        (, uint256 shares) = bentoBox.deposit(IERC20(sushiBar), address(this), address(this), ISushiBar(sushiBar).balanceOf(address(this)), 0); // stake resulting xSUSHI into BENTO
        nyanMint(to, shares * multiplier);
    }

    /// @dev Leave NyanSushi. Claim back your SUSHI.
    function unNyanSUSHI(address to, uint256 amount) external {
        nyanBurn(amount);
        (uint256 amountOut, ) = bentoBox.withdraw(IERC20(sushiBar), address(this), address(this), 0, amount / multiplier); // withdraw adjusted xSUSHI share amount from BENTO
        ISushiBar(sushiBar).leave(amountOut); // burn resulting xSUSHI into SUSHI
        sushiToken.transfer(to, sushiToken.balanceOf(address(this))); // transfer resulting SUSHI to `to`
    }
    
    /// **** HELPER FUNCTIONS ****
    /// @dev Fallback, sent ETH gives caller corresponding NYAN.
    receive() external payable {
        (uint256 reserve0, uint256 reserve1, ) = sushiSwapSushiETHpair.getReserves();
        uint256 amountInWithFee = msg.value * 997;
        uint256 out = (amountInWithFee * reserve0) / (reserve1 * 1000) + amountInWithFee;
        IWETH9(wETH9).deposit{value: msg.value}();
        IWETH9(wETH9).transfer(address(sushiSwapSushiETHpair), msg.value);
        sushiSwapSushiETHpair.swap(out, 0, address(this), "");
        ISushiBar(sushiBar).enter(sushiToken.balanceOf(address(this))); // stake resulting SUSHI into xSUSHI
        (, uint256 shares) = bentoBox.deposit(IERC20(sushiBar), address(this), address(this), ISushiBar(sushiBar).balanceOf(address(this)), 0); // stake resulting xSUSHI into BENTO
        nyanMint(msg.sender, shares * multiplier);
    }
    
    /// @dev Internal mint function for {nyan} and {nyanSUSHI}.
    function nyanMint(address to, uint256 amount) private {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    /// @dev Internal burn function for {unNyan} and {unNyanSUSHI}.
    function nyanBurn(uint256 amount) private {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
