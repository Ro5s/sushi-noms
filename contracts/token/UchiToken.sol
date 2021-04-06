/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// @notice Simple restricted token with SushiSwap launch and minimal governance.
contract UchiToken {
    ILAUNCHSUSHISWAP constant private sushiSwapFactory = ILAUNCHSUSHISWAP(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
    ILAUNCHSUSHISWAP constant private sushiSwapRouter = ILAUNCHSUSHISWAP(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    address constant private wETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C; 
    
    address public owner;
    address public sushiPair;
    string public name;
    string public symbol;
    uint8 constant public decimals = 18;
    uint256 public totalSupply;
    uint256 immutable public timeRestrictionEnds; 
    bool public timeRestricted;
    bool public whiteListRestricted;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public whitelisted;
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    
    constructor(
        address _owner,
        address[] memory uchi,
        string memory _name, 
        string memory _symbol, 
        uint256 _timeRestrictionEnds,
        uint256[] memory uchiSupply) {
        for (uint256 i = 0; i < uchi.length; i++) {
            balanceOf[uchi[i]] = uchiSupply[i];
            whitelisted[uchi[i]] = true;
            totalSupply += uchiSupply[i];
            emit Transfer(address(0), uchi[i], uchiSupply[i]);
        }
        
        owner = _owner; 
        name = _name;
        symbol = _symbol;
        timeRestrictionEnds = _timeRestrictionEnds;
        timeRestricted = true;
        whiteListRestricted = true;
    }
    
    function initMarket(address collateral, address _owner, uint256 collateralSupply, uint256 poolSupply) external payable {
        sushiPair = sushiSwapFactory.createPair(collateral, address(this));
        balanceOf[address(this)] = poolSupply;
        this.approve(address(sushiSwapRouter), poolSupply);
        if (collateral == wETH) {
            sushiSwapRouter.addLiquidityETH{value: msg.value}(address(this), poolSupply, 0, 0, _owner, block.timestamp+120);
        } else {
            sushiSwapRouter.addLiquidity(address(this), collateral, poolSupply, collateralSupply, 0, 0, _owner, block.timestamp+120);
        }
        balanceOf[address(this)] = type(uint256).max; // deny transfers to this contract without gas burden
    }
    
    /// - RESTRICTED ERC20 - ///
    function approve(address to, uint256 amount) public returns (bool) {
        allowance[msg.sender][to] = amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        if (timeRestricted) {require(block.timestamp >= timeRestrictionEnds, "!time");} // 
        if (whiteListRestricted) {require(whitelisted[msg.sender] && whitelisted[to], "!whitelisted");} //
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (timeRestricted) {require(block.timestamp >= timeRestrictionEnds, "!time");} // 
        if (whiteListRestricted) {require(whitelisted[from] && whitelisted[to], "!whitelisted");} // 
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    /// - GOVERNANCE - ///
    function updateGovernance(address _owner, bool _whiteListRestricted) external {
        require(msg.sender == owner, "!owner");
        owner = _owner;
        whiteListRestricted = _whiteListRestricted;
        // remove time restriction flag if ended - this saves gas in transfer checks and makes timing trustless
        if (block.timestamp >= timeRestrictionEnds) {timeRestricted = false;}
    }
    
    function updateWhitelist(address[] calldata account, bool[] calldata approved) external {
        require(msg.sender == owner, "!owner");
        for (uint256 i = 0; i < account.length; i++) {
            whitelisted[account[i]] = approved[i];
        }
    }
}

/// @notice Interface for SushiSwap pair creation and liquidity provision.
interface ILAUNCHSUSHISWAP {
    function approve(address spender, uint256 amount) external returns (bool);
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    function createPair(address tokenA, address tokenB) external returns (address pair);
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

/// @notice Factory for Uchi Token creation.
contract UchiTokenFactory {
    event DeployUchiToken(address indexed uchiToken);
    
    function deployUchiToken(
        address[] memory uchi,
        address collateral,
        string memory _name, 
        string memory _symbol, 
        uint256 collateralSupply,
        uint256 poolSupply,
        uint256 _timeRestrictionEnds,
        uint256[] memory uchiSupply) external payable {
        address _owner = uchi[0]; // first `uchi` is `owner`
        UchiToken uchiToken = new UchiToken(
            _owner,
            uchi,
            _name, 
            _symbol, 
            _timeRestrictionEnds,
            uchiSupply);
        
        uchiToken.initMarket(collateral, _owner, collateralSupply, poolSupply);
        
        emit DeployUchiToken(address(uchiToken));
    }
}
