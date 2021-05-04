// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
/// @notice Dummy ERC20 interface for params.  
interface IERC20 {} 

/// @notice Interface for BentoBox ERC20 vault transfers.
interface IBentoBoxV1TransferHelper {
    function balanceOf(IERC20, address) external view returns (uint256);

    function transfer(
        IERC20 token,
        address from,
        address to,
        uint256 share
    ) external;

    function transferMultiple(
        IERC20 token,
        address from,
        address[] calldata tos,
        uint256[] calldata shares
    ) external;
}

/// @notice Interface for low-level Boshi `swap()` call.
interface IBoshiCallee {
    function boshiCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

/// @notice Interface for LP migration to Boshi 'pair'.
interface IMigrator { 
    /// @dev Return amount of liquidity token that migrator wants.
    function desiredLiquidity() external view returns (uint256);
}

// @notice A library for performing various math operations, including overflow/underflow checks and handling binary fixed point numbers,
// based on awesomeness from DappHub, @Boring_Crypto and Uniswap V2.
library BoshiMath {
    uint224 constant Q112 = 2**112;
    
    /// @dev Encode uint112 as UQ112x112.
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    /// @dev Divide UQ112x112 by uint112, returning UQ112x112.
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
    
    function min(uint x, uint y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    /// @dev Babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method).
    function sqrt(uint y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
    /// **** SAFE MATH **** 
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a + b) >= b, "BoshiMath: Add Overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a - b) <= a, "BoshiMath: Underflow");
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b == 0 || (c = a * b) / b == a, "BoshiMath: Mul Overflow");
    }
}

// File @boringcrypto/boring-solidity/contracts/BoringOwnable.sol@v1.2.0
// License-Identifier: MIT

// Audit on 5-Jan-2021 by Keno and BoringCrypto
// Source: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol + Claimable.sol
// Edited by BoringCrypto

contract BoringOwnableData {
    address public owner;
    address public pendingOwner;
}

contract BoringOwnable is BoringOwnableData {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice `owner` defaults to msg.sender on construction.
    constructor() public {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Transfers ownership to `newOwner`. Either directly or claimable by the new pending owner.
    /// Can only be invoked by the current `owner`.
    /// @param newOwner Address of the new owner.
    /// @param direct True if `newOwner` should be set immediately. False if `newOwner` needs to use `claimOwnership`.
    /// @param renounce Allows the `newOwner` to be `address(0)` if `direct` and `renounce` is True. Has no effect otherwise.
    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) public onlyOwner {
        if (direct) {
            // Checks
            require(newOwner != address(0) || renounce, "Ownable: zero address");

            // Effects
            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
            pendingOwner = address(0);
        } else {
            // Effects
            pendingOwner = newOwner;
        }
    }

    /// @notice Needs to be called by `pendingOwner` to claim ownership.
    function claimOwnership() public {
        address _pendingOwner = pendingOwner;

        // Checks
        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        // Effects
        emit OwnershipTransferred(owner, _pendingOwner);
        owner = _pendingOwner;
        pendingOwner = address(0);
    }

    /// @notice Only allows the `owner` to execute the function.
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}

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

    constructor() public {
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

// solhint-disable no-inline-assembly
// solhint-disable not-rely-on-time

// Data part taken out for building of contracts that receive delegate calls
contract ERC20Data {
    /// @notice owner > balance mapping.
    mapping(address => uint256) public balanceOf;
    /// @notice owner > spender > allowance mapping.
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice owner > nonce mapping. Used in `permit`.
    mapping(address => uint256) public nonces;
}

/// @notice ERC20 extended for Boshi 'pair'.
contract BoshiERC20 is Domain, ERC20Data {
    using BoshiMath for uint256;
    
    string public constant name = 'Boshi LP Token';
    string public constant symbol = 'bSLP';
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    
    /// @dev Internal Boshi pair LP mint.
    function _mint(address to, uint256 amount) internal {
        totalSupply = totalSupply.add(amount);
        balanceOf[to] = balanceOf[to].add(amount);
        emit Transfer(address(0), to, amount);
    }
    
    /// @dev Internal Boshi pair LP burn.
    function _burn(address from, uint256 amount) internal {
        balanceOf[from] = balanceOf[from].sub(amount);
        totalSupply = totalSupply.sub(amount);
        emit Transfer(from, address(0), amount);
    }

    /// @notice Transfers `amount` tokens from `msg.sender` to `to`.
    /// @param to The address to move the tokens.
    /// @param amount of the tokens to move.
    /// @return (bool) Returns True if succeeded.
    function transfer(address to, uint256 amount) external returns (bool) {
        // If `amount` is 0, or `msg.sender` is `to` nothing happens
        if (amount != 0) {
            uint256 srcBalance = balanceOf[msg.sender];
            require(srcBalance >= amount, "BoshiERC20: balance too low");
            if (msg.sender != to) {
                require(to != address(0), "BoshiERC20: no zero address"); // Moved down so low balance calls safe some gas

                balanceOf[msg.sender] = srcBalance - amount; // Underflow is checked
                balanceOf[to] += amount; // Can't overflow because totalSupply would be greater than 2^256-1
            }
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Transfers `amount` tokens from `from` to `to`. Caller needs approval for `from`.
    /// @param from Address to draw tokens from.
    /// @param to The address to move the tokens.
    /// @param amount The token amount to move.
    /// @return (bool) Returns True if succeeded.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        // If `amount` is 0, or `from` is `to` nothing happens
        if (amount != 0) {
            uint256 srcBalance = balanceOf[from];
            require(srcBalance >= amount, "BoshiERC20: balance too low");

            if (from != to) {
                uint256 spenderAllowance = allowance[from][msg.sender];
                // If allowance is infinite, don't decrease it to save on gas (breaks with EIP-20).
                if (spenderAllowance != type(uint256).max) {
                    require(spenderAllowance >= amount, "BoshiERC20: allowance too low");
                    allowance[from][msg.sender] = spenderAllowance - amount; // Underflow is checked
                }
                require(to != address(0), "BoshiERC20: no zero address"); // Moved down so other failed calls save some gas

                balanceOf[from] = srcBalance - amount; // Underflow is checked
                balanceOf[to] += amount; // Can't overflow because totalSupply would be greater than 2^256-1
            }
        }
        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice Approves `amount` from sender to be spend by `spender`.
    /// @param spender Address of the party that can draw from msg.sender's account.
    /// @param amount The maximum collective amount that `spender` can draw.
    /// @return (bool) Returns True if approved.
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant PERMIT_SIGNATURE_HASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice Approves `value` from `owner_` to be spend by `spender`.
    /// @param owner_ Address of the owner.
    /// @param spender The address of the spender that gets approved to draw from `owner_`.
    /// @param value The maximum collective amount that `spender` can draw.
    /// @param deadline This permit must be redeemed before this deadline (UTC timestamp in seconds).
    function permit(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(owner_ != address(0), "ERC20: Owner cannot be 0");
        require(block.timestamp < deadline, "ERC20: Expired");
        require(
            ecrecover(_getDigest(keccak256(abi.encode(PERMIT_SIGNATURE_HASH, owner_, spender, value, nonces[owner_]++, deadline))), v, r, s) ==
                owner_,
            "ERC20: Invalid Signature"
        );
        allowance[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }
}

/// @title BoshiPairV1
/// @notice SushiSwap on BentoBoxV1.
contract BoshiPairV1 is BoringOwnable, BoshiERC20 {
    using BoshiMath for uint256;
    using BoshiMath for uint224;
    
    /// @dev Fixed variables (for `masterContract` and all 'pair' clones).
    IBentoBoxV1TransferHelper private constant bentoBox = IBentoBoxV1TransferHelper(0xF5BCE5077908a1b7370B9ae04AdC565EBd643966); // BentoBoxV1 vault
    BoshiPairV1 public immutable masterContract; // Boshi 'master' for clones

    /// @notice `masterContract` variables.
    address public feeTo;
    address public feeToSetter;
    address public migrator;
    
    mapping(IERC20 => mapping(IERC20 => address)) public getPair;
    address[] public allPairs;
    
    /// @notice Boshi 'pair' clone variables.
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    IERC20 public token0;
    IERC20 public token1;
    
    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Boshi: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'Boshi: EXPIRED');
        _;
    }
    
    function pushPair(address pair) external {
        require(msg.sender == address(this), 'Boshi: FORBIDDEN');
        allPairs.push(pair);
    }  
    
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    
    event PairCreated(IERC20 indexed token0, IERC20 indexed token1, address pair, uint256); // 'master' event
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    /// @notice The constructor is only used for the initial `masterContract`. Subsequent clones are initialized via `init()`.
    constructor() public {
        masterContract = this;
        feeTo = msg.sender;
    }
    
    /// @notice Serves as the constructor for clones, as clones can't have a regular constructor.
    /// @dev `data` is abi-encoded in the format: (IERC20 tokenA, IERC20 tokenB).
    function init(bytes calldata data) external {
        require(address(token0) == address(0), 'BoshiPair: ALREADY_INITIALIZED');
        (IERC20 tokenA, IERC20 tokenB) = abi.decode(data, (IERC20, IERC20));
        require(tokenA != tokenB, 'Boshi: IDENTICAL_ADDRESSES');
        (IERC20 _token0, IERC20 _token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(address(_token0) != address(0), 'Boshi: ZERO_ADDRESS');
        require(masterContract.getPair(_token0, _token1) == address(0), 'Boshi: PAIR_EXISTS'); // single check is sufficient
        masterContract.getPair(_token0, _token1) == address(this);
        masterContract.getPair(_token1, _token0) == address(this); // populate mapping in the reverse direction
        masterContract.pushPair(address(this));
        token0 = _token0;
        token1 = _token1;
        emit PairCreated(_token0, _token1, address(this), masterContract.allPairsLength());
    }

    /// @notice Update reserves and, on the first call per block, price accumulators.
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'Boshi: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint256(BoshiMath.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(BoshiMath.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /// @notice If fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k).
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address _feeTo = masterContract.feeTo();
        feeOn = _feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = BoshiMath.sqrt(uint256(_reserve0).mul(_reserve1));
                uint256 rootKLast = BoshiMath.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /// @notice This low-level function should be called from a contract which performs important safety checks.
    function mint(address to) public lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        uint256 balance0 = bentoBox.balanceOf(token0, address(this));
        uint256 balance1 = bentoBox.balanceOf(token1, address(this));
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            IMigrator _migrator = IMigrator(masterContract.migrator());
            if (msg.sender == address(_migrator)) {
                liquidity = _migrator.desiredLiquidity();
                require(liquidity > 0 && liquidity != type(uint256).max, 'Boshi: BAD_DESIRED_LIQUIDITY');
            } else {
                require(address(_migrator) == address(0), 'Boshi: MUST_NOT_HAVE_MIGRATOR');
                liquidity = BoshiMath.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
                _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
            }
        } else {
            liquidity = BoshiMath.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'Boshi: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @notice This low-level function should be called from a contract which performs important safety checks.
    function burn(address to) public lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        IERC20 _token0 = token0;                                 // gas savings
        IERC20 _token1 = token1;                                 // gas savings
        uint256 balance0 = bentoBox.balanceOf(_token0, address(this));
        uint256 balance1 = bentoBox.balanceOf(_token1, address(this));
        uint256 liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'Boshi: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        bentoBox.transfer(_token0, address(this), to, amount0);
        bentoBox.transfer(_token1, address(this), to, amount1);
        balance0 = bentoBox.balanceOf(_token0, address(this));
        balance1 = bentoBox.balanceOf(_token1, address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice This low-level function should be called from a contract which performs important safety checks.
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'Boshi: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Boshi: INSUFFICIENT_LIQUIDITY');
        
        uint256 balance0;
        uint256 balance1;
        { // scope for _token{0,1} avoids stack too deep errors
        IERC20 _token0 = token0;
        IERC20 _token1 = token1;
        require(to != address(_token0) && to != address(_token1), 'Boshi: INVALID_TO');
        if (amount0Out > 0) bentoBox.transfer(_token0, address(this), to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) bentoBox.transfer(_token1, address(this), to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IBoshiCallee(to).boshiCall(msg.sender, amount0Out, amount1Out, data);
        balance0 = bentoBox.balanceOf(_token0, address(this));
        balance1 = bentoBox.balanceOf(_token1, address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'Boshi: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1} Adjusted, avoids stack too deep errors
        uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint256(_reserve0).mul(_reserve1).mul(1000**2), 'Boshi: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
    
    /// **** ADD LIQUIDITY ****
    function addLiquidity(
        uint amount0Desired,
        uint amount1Desired,
        uint amount0Min,
        uint amount1Min,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        if (_reserve0 == 0 && _reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint amount1Optimal = amount0Desired.mul(_reserve1) / _reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, 'Boshi: INSUFFICIENT_1_AMOUNT');
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint amount0Optimal = amount1Desired.mul(_reserve1) / _reserve0;
                assert(amount0Optimal <= amount0Desired);
                require(amount0Optimal >= amount0Min, 'Boshi: INSUFFICIENT_0_AMOUNT');
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
        bentoBox.transfer(token0, msg.sender, address(this), amount0);
        bentoBox.transfer(token1, msg.sender, address(this), amount1);
        liquidity = mint(to);
    }
    
    /// **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        uint liquidity,
        uint amount0Min,
        uint amount1Min,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amount0, uint amount1) {
        this.transferFrom(msg.sender, address(this), liquidity); // send liquidity to this pair
        (amount0, amount1) = burn(to);
        require(amount0 >= amount0Min, 'Boshi: INSUFFICIENT_0_AMOUNT');
        require(amount1 >= amount1Min, 'Boshi: INSUFFICIENT_1_AMOUNT');
    }

    /// **** GOVERNANCE **** 
    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function setMigrator(address _migrator) external onlyOwner {
        migrator = _migrator;
    }
}
