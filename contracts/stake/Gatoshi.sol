// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.6;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Interface of the ERC2612 standard as defined in the EIP.
 *
 * Adds the {permit} method, which can be used to change one's
 * {IERC20-allowance} without having to send a transaction, by signing a
 * message. This allows users to spend tokens without having to hold Ether.
 *
 * See https://eips.ethereum.org/EIPS/eip-2612.
 */
interface IERC2612 {
    /**
     * @dev Sets `value` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be `address(0)`.
     * - `spender` cannot be `address(0)`.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use `owner`'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Returns the current ERC2612 nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases `owner`'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);
    
    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by EIP712.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

interface IERC3156FlashBorrower {

    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

interface IERC3156FlashLender {

    /**
     * @dev The amount of currency available to be lended.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(
        address token
    ) external view returns (uint256);

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(
        address token,
        uint256 amount
    ) external view returns (uint256);

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

interface ITransferReceiver {
    function onTokenTransfer(address, uint, bytes calldata) external returns (bool);
}

interface IApprovalReceiver {
    function onTokenApproval(address, uint, bytes calldata) external returns (bool);
}

/// @notice Interface for depositing into and withdrawing from BentoBox vault.
interface IBentoBoxBasic {
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
interface ISushiBarBridge { 
    function enter(uint256 amount) external;
    function leave(uint256 share) external;
}

/// @notice Interface for SushiSwap.
interface ISushiSwap {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

/// @notice Interface for Ether wrapper contract v9.
interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

/// - make 18 decimals add scaling factor to GATO shares?
/// - add bentobox withdrawals ~~ 
/// @notice Staking contract for xSUSHI with extra fun stuff.
contract Gatoshi is IERC20 {
    IBentoBoxBasic constant bentoBox = IBentoBoxBasic(0xF5BCE5077908a1b7370B9ae04AdC565EBd643966); // BENTO vault contract
    IERC20 constant sushiToken = IERC20(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2); // SUSHI token contract
    address constant sushiBar = 0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272; // xSUSHI staking contract for SUSHI
    ISushiSwap constant sushiSwapSushiETHpair = ISushiSwap(0x795065dCc9f64b5614C407a6EFDC400DA6221FB0); // SUSHI/ETH pair on SushiSwap
    address constant wETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // ETH wrapper contract v9
    
    string public constant name = "Gatoshi";
    string public constant symbol = "GATO";
    uint8  public constant decimals = 15;
    uint256 public override totalSupply;

    bytes32 public immutable CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bytes32 public immutable PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    uint256 public immutable deploymentChainId;
    bytes32 immutable _DOMAIN_SEPARATOR;

    /// @dev Records amount of GATO token owned by account.
    mapping (address => uint256) public override balanceOf;

    /// @dev Records current ERC2612 nonce for account. This value must be included whenever signature is generated for {permit}.
    /// Every successful call to {permit} increases account's nonce by one. This prevents signature from being used multiple times.
    mapping (address => uint256) public nonces;

    /// @dev Records number of GATO token that account (second) will be allowed to spend on behalf of another account (first) through {transferFrom}.
    mapping (address => mapping (address => uint256)) public override allowance;

    /// @dev Current amount of flash-minted GATO token.
    uint256 public flashMinted;
    
    constructor() {
        uint256 chainId;
        assembly {chainId := chainid()}
        deploymentChainId = chainId;
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(chainId);
    }

    /// @dev Calculates the DOMAIN_SEPARATOR.
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /// @dev Returns the DOMAIN_SEPARATOR.
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        uint256 chainId;
        assembly {chainId := chainid()}
        return chainId == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(chainId);
    }

    /// @dev Fallback, `msg.value` of ETH sent to this contract grants caller account a corresponding increase in GATO token balance through `sushiBar` and `sushiSwapSushiETHpair`.
    /// Emits {Transfer} event to reflect GATO token mint of `msg.value` from `address(0)` to caller account.
    receive() external payable {
        // _mintTo(msg.sender, value);
        (uint256 reserve0, uint256 reserve1, ) = sushiSwapSushiETHpair.getReserves();
        uint256 amountInWithFee = msg.value * 997;
        uint256 out = (amountInWithFee * reserve0) / (reserve1 * 1000) + amountInWithFee;
        IWETH9(wETH9).deposit{value: msg.value}();
        IERC20(wETH9).transfer(address(sushiSwapSushiETHpair), msg.value);
        sushiSwapSushiETHpair.swap(out, 0, address(this), "");
        ISushiBarBridge(sushiBar).enter(sushiToken.balanceOf(address(this))); // stake resulting SUSHI into `sushiBar` xSUSHI
        uint256 balance = IERC20(sushiBar).balanceOf(address(this));
        bentoBox.deposit(IERC20(sushiBar), address(this), address(this), balance, 0); // stake resulting xSUSHI into BENTO for `to`
        balanceOf[msg.sender] += balance;
        totalSupply += balance;
        emit Transfer(address(0), msg.sender, balance);
    }

    /// @dev `value` of xSUSHI sent to this contract grants caller account a corresponding increase in GATO token balance.
    /// Emits {Transfer} event to reflect GATO token mint of `value` from `address(0)` to caller account.
    function deposit(uint256 value) external {
        // _mintTo(msg.sender, value);
        IERC20(sushiBar).transferFrom(msg.sender, address(this), value);
        bentoBox.deposit(IERC20(sushiBar), address(this), address(this), value, 0); // stake `value` xSUSHI into BENTO for caller
        balanceOf[msg.sender] += value;
        totalSupply += value;
        emit Transfer(address(0), msg.sender, value);
    }

    /// @dev `value` of xSUSHI sent to this contract grants `to` account a corresponding increase in GATO token balance.
    /// Emits {Transfer} event to reflect GATO token mint of `value` from `address(0)` to `to` account.
    function depositTo(address to, uint256 value) external {
        // _mintTo(to, value)
        IERC20(sushiBar).transferFrom(msg.sender, address(this), value);
        bentoBox.deposit(IERC20(sushiBar), address(this), address(this), value, 0); // stake `value` xSUSHI into BENTO for `to`
        balanceOf[to] += value;
        totalSupply += value;
        emit Transfer(address(0), to, value);
    }

    /// @dev `value` of xSUSHI sent to this contract grants `to` account a corresponding increase in GATO token balance,
    /// after which a call is executed to an ERC677-compliant contract with the `data` parameter.
    /// Emits {Transfer} event.
    /// Returns boolean value indicating whether operation succeeded.
    /// For more information on {transferAndCall} format, see https://github.com/ethereum/EIPs/issues/677.
    function depositToAndCall(address to, uint256 value, bytes calldata data) external returns (bool success) {
        // _mintTo(to, value);
        IERC20(sushiBar).transferFrom(msg.sender, address(this), value);
        bentoBox.deposit(IERC20(sushiBar), address(this), address(this), value, 0); // stake `value` xSUSHI into BENTO for `to`
        balanceOf[to] += value;
        totalSupply += value;
        emit Transfer(address(0), to, value);

        return ITransferReceiver(to).onTokenTransfer(msg.sender, value, data);
    }

    /// @dev Returns the amount of GATO token that can be flash-lent.
    function maxFlashLoan(address token) external view returns (uint256) {
        return token == address(this) ? type(uint112).max - flashMinted : 0; // Can't underflow
    }

    /// @dev Returns the fee (zero) for flash lending an amount of GATO token.
    function flashFee(address token, uint256) external view returns (uint256) {
        require(token == address(this), "GATO: flash mint only GATO");
        return 0;
    }

    /// @dev Flash lends `value` GATO token to the receiver address.
    /// By the end of the transaction, `value` GATO token will be burned from the receiver.
    /// The flash-minted GATO token is not backed by real xSUSHI, but can be withdrawn as such up to the xSUSHI balance of this contract.
    /// Arbitrary data can be passed as a bytes calldata parameter.
    /// Emits {Approval} event to reflect reduced allowance `value` for this contract to spend from receiver account (`receiver`),
    /// unless allowance is set to `type(uint256).max`
    /// Emits two {Transfer} events for minting and burning of the flash-minted amount.
    /// Returns boolean value indicating whether operation succeeded.
    /// Requirements:
    ///   - `value` must be less or equal to type(uint112).max.
    ///   - The total of all flash loans in a tx must be less or equal to type(uint112).max.
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 value, bytes calldata data) external returns (bool) {
        require(token == address(this), "GATO: flash mint only GATO");
        require(value <= type(uint112).max, "GATO: individual loan limit exceeded");
        flashMinted = flashMinted + value;
        require(flashMinted <= type(uint112).max, "GATO: total loan limit exceeded");
        
        // _mintTo(address(receiver), value);
        balanceOf[address(receiver)] += value;
        emit Transfer(address(0), address(receiver), value);

        require(
            receiver.onFlashLoan(msg.sender, address(this), value, 0, data) == CALLBACK_SUCCESS,
            "GATO: flash loan failed"
        );
        
        // _decreaseAllowance(address(receiver), address(this), value);
        uint256 allowed = allowance[address(receiver)][address(this)];
        if (allowed != type(uint256).max) {
            require(allowed >= value, "GATO: request exceeds allowance");
            uint256 reduced = allowed - value;
            allowance[address(receiver)][address(this)] = reduced;
            emit Approval(address(receiver), address(this), reduced);
        }

        // _burnFrom(address(receiver), value);
        uint256 balance = balanceOf[address(receiver)];
        require(balance >= value, "GATO: burn amount exceeds balance");
        balanceOf[address(receiver)] = balance - value;
        emit Transfer(address(receiver), address(0), value);
        
        flashMinted = flashMinted - value;
        return true;
    }

    /// @dev Burns `value` GATO token from caller account and withdraw corresponding xSUSHI to the same.
    /// Emits {Transfer} event to reflect GATO token burn of `value` to `address(0)` from caller account. 
    /// Requirements:
    ///   - caller account must have at least `value` balance of GATO token.
    function withdraw(uint256 value) external {
        // _burnFrom(msg.sender, value);
        uint256 balance = balanceOf[msg.sender];
        require(balance >= value, "GATO: burn amount exceeds balance");
        balanceOf[msg.sender] = balance - value;
        totalSupply -= value;
        emit Transfer(msg.sender, address(0), value);

        // _transfer(msg.sender, value);  
        IERC20(sushiBar).transfer(msg.sender, value);
    }

    /// @dev Burns `value` GATO token from caller account and withdraw corresponding xSUSHI to account (`to`).
    /// Emits {Transfer} event to reflect GATO token burn of `value` to `address(0)` from caller account.
    /// Requirements:
    ///   - caller account must have at least `value` balance of GATO token.
    function withdrawTo(address payable to, uint256 value) external {
        // _burnFrom(msg.sender, value);
        uint256 balance = balanceOf[msg.sender];
        require(balance >= value, "GATO: burn amount exceeds balance");
        balanceOf[msg.sender] = balance - value;
        totalSupply -= value;
        emit Transfer(msg.sender, address(0), value);

        // _transfer(to, value);        
        IERC20(sushiBar).transfer(to, value);
    }

    /// @dev Burns `value` GATO token from account (`from`) and withdraw corresponding xSUSHI to account (`to`).
    /// Emits {Approval} event to reflect reduced allowance `value` for caller account to spend from account (`from`),
    /// unless allowance is set to `type(uint256).max`
    /// Emits {Transfer} event to reflect GATO token burn of `value` to `address(0)` from account (`from`).
    /// Requirements:
    ///   - `from` account must have at least `value` balance of GATO token.
    ///   - `from` account must have approved caller to spend at least `value` of GATO token, unless `from` and caller are the same account.
    function withdrawFrom(address from, address payable to, uint256 value) external {
        if (from != msg.sender) {
            // _decreaseAllowance(from, msg.sender, value);
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value, "GATO: request exceeds allowance");
                uint256 reduced = allowed - value;
                allowance[from][msg.sender] = reduced;
                emit Approval(from, msg.sender, reduced);
            }
        }
        
        // _burnFrom(from, value);
        uint256 balance = balanceOf[from];
        require(balance >= value, "GATO: burn amount exceeds balance");
        balanceOf[from] = balance - value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);

        // _transfer(to, value);        
        IERC20(sushiBar).transfer(to, value);
    }

    /// @dev Sets `value` as allowance of `spender` account over caller account's GATO token.
    /// Emits {Approval} event.
    /// Returns boolean value indicating whether operation succeeded.
    function approve(address spender, uint256 value) external override returns (bool) {
        // _approve(msg.sender, spender, value);
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);

        return true;
    }

    /// @dev Sets `value` as allowance of `spender` account over caller account's GATO token,
    /// after which a call is executed to an ERC677-compliant contract with the `data` parameter.
    /// Emits {Approval} event.
    /// Returns boolean value indicating whether operation succeeded.
    /// For more information on {approveAndCall} format, see https://github.com/ethereum/EIPs/issues/677.
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool) {
        // _approve(msg.sender, spender, value);
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        
        return IApprovalReceiver(spender).onTokenApproval(msg.sender, value, data);
    }

    /// @dev Sets `value` as allowance of `spender` account over `owner` account's GATO token, given `owner` account's signed approval.
    /// Emits {Approval} event.
    /// Requirements:
    ///   - `deadline` must be timestamp in future.
    ///   - `v`, `r` and `s` must be valid `secp256k1` signature from `owner` account over EIP712-formatted function arguments.
    ///   - the signature must use `owner` account's current nonce (see {nonces}).
    ///   - the signer cannot be `address(0)` and must be `owner` account.
    /// For more information on signature format, see https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP section].
    /// GATO token implementation adapted from https://github.com/albertocuestacanada/ERC20Permit/blob/master/contracts/ERC20Permit.sol.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(block.timestamp <= deadline, "GATO: Expired permit");

        uint256 chainId;
        assembly {chainId := chainid()}

        bytes32 hashStruct = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonces[owner]++,
                deadline));

        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                chainId == deploymentChainId ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(chainId),
                hashStruct));

        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0) && signer == owner, "GATO: invalid permit");

        // _approve(owner, spender, value);
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /// @dev Moves `value` GATO token from caller's account to account (`to`).
    /// A transfer to `address(0)` triggers an xSUSHI withdraw matching the sent GATO token in favor of caller.
    /// Emits {Transfer} event.
    /// Returns boolean value indicating whether operation succeeded.
    /// Requirements:
    ///   - caller account must have at least `value` GATO token.
    function transfer(address to, uint256 value) external override returns (bool) {
        // _transferFrom(msg.sender, to, value);
        if (to != address(0)) { // Transfer
            uint256 balance = balanceOf[msg.sender];
            require(balance >= value, "GATO: transfer amount exceeds balance");

            balanceOf[msg.sender] = balance - value;
            balanceOf[to] += value;
            emit Transfer(msg.sender, to, value);
        } else { // Withdraw
            uint256 balance = balanceOf[msg.sender];
            require(balance >= value, "GATO: burn amount exceeds balance");
            balanceOf[msg.sender] = balance - value;
            emit Transfer(msg.sender, address(0), value);
            
            // _transfer(msg.sender, value);  
            IERC20(sushiBar).transfer(msg.sender, value);
        }
        
        return true;
    }

    /// @dev Moves `value` GATO token from account (`from`) to account (`to`) using allowance mechanism.
    /// `value` is then deducted from caller account's allowance, unless set to `type(uint256).max`.
    /// A transfer to `address(0)` triggers an xSUSHI withdraw matching the sent GATO token in favor of caller.
    /// Emits {Approval} event to reflect reduced allowance `value` for caller account to spend from account (`from`),
    /// unless allowance is set to `type(uint256).max`
    /// Emits {Transfer} event.
    /// Returns boolean value indicating whether operation succeeded.
    /// Requirements:
    ///   - `from` account must have at least `value` balance of GATO token.
    ///   - `from` account must have approved caller to spend at least `value` of GATO token, unless `from` and caller are the same account.
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        if (from != msg.sender) {
            // _decreaseAllowance(from, msg.sender, value);
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value, "GATO: request exceeds allowance");
                uint256 reduced = allowed - value;
                allowance[from][msg.sender] = reduced;
                emit Approval(from, msg.sender, reduced);
            }
        }
        
        // _transferFrom(from, to, value);
        if (to != address(0)) { // Transfer
            uint256 balance = balanceOf[from];
            require(balance >= value, "GATO: transfer amount exceeds balance");

            balanceOf[from] = balance - value;
            balanceOf[to] += value;
            emit Transfer(from, to, value);
        } else { // Withdraw
            uint256 balance = balanceOf[from];
            require(balance >= value, "GATO: burn amount exceeds balance");
            balanceOf[from] = balance - value;
            emit Transfer(from, address(0), value);
        
            // _transfer(msg.sender, value);  
            IERC20(sushiBar).transfer(msg.sender, value);
        }
        
        return true;
    }

    /// @dev Moves `value` GATO token from caller's account to account (`to`), 
    /// after which a call is executed to an ERC677-compliant contract with the `data` parameter.
    /// A transfer to `address(0)` triggers an xSUSHI withdraw matching the sent GATO token in favor of caller.
    /// Emits {Transfer} event.
    /// Returns boolean value indicating whether operation succeeded.
    /// Requirements:
    ///   - caller account must have at least `value` GATO token.
    /// For more information on {transferAndCall} format, see https://github.com/ethereum/EIPs/issues/677.
    function transferAndCall(address to, uint value, bytes calldata data) external returns (bool) {
        // _transferFrom(msg.sender, to, value);
        if (to != address(0)) { // Transfer
            uint256 balance = balanceOf[msg.sender];
            require(balance >= value, "GATO: transfer amount exceeds balance");

            balanceOf[msg.sender] = balance - value;
            balanceOf[to] += value;
            emit Transfer(msg.sender, to, value);
        } else { // Withdraw
            uint256 balance = balanceOf[msg.sender];
            require(balance >= value, "GATO: burn amount exceeds balance");
            balanceOf[msg.sender] = balance - value;
            emit Transfer(msg.sender, address(0), value);
        
            // _transfer(msg.sender, value);  
            IERC20(sushiBar).transfer(msg.sender, value);
        }

        return ITransferReceiver(to).onTokenTransfer(msg.sender, value, data);
    }
}
