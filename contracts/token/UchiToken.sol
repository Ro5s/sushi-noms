/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// @notice Interface for ERC20 token forwarding.
interface IERC20FWD { 
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Interface for SushiSwap pair creation and liquidity provision.
interface ILAUNCHSUSHISWAP {
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

/// @notice Simple restricted token with SushiSwap launch and minimal governance.
contract UchiToken {
    ILAUNCHSUSHISWAP constant private sushiSwapFactory = ILAUNCHSUSHISWAP(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
    ILAUNCHSUSHISWAP constant private sushiSwapRouter = ILAUNCHSUSHISWAP(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    
    address public owner;
    address public sushiPair; // Uchi SushiSwap pair
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
        address[] memory uchi,
        address collateral,
        string memory _name, 
        string memory _symbol, 
        uint256[] memory uchiSupply,
        uint256 collateralSupply,
        uint256 poolSupply,
        uint256 _timeRestrictionEnds
    ) {
        for (uint256 i = 0; i < uchi.length; i++) {
            balanceOf[uchi[i]] = uchiSupply[i];
            whitelisted[uchi[i]] = true;
            totalSupply += uchiSupply[i];
            emit Transfer(address(0), uchi[i], uchiSupply[i]);
        }
        
        owner = uchi[0]; // set `owner` of this contract to first `uchi` address in array 
        balanceOf[address(this)] = type(uint256).max; // trick to deny transfers to this contract
        
        name = _name;
        symbol = _symbol;
        timeRestrictionEnds = _timeRestrictionEnds;
        timeRestricted = true;
        whiteListRestricted = true;
        
        sushiPair = sushiSwapFactory.createPair(collateral, address(this));
        
        if (collateral == address(0)) {
            sushiSwapRouter.addLiquidityETH{value: address(this).balance}(address(this), poolSupply, 0, 0, owner, 0);
        } else {
            sushiSwapRouter.addLiquidity(address(this), collateral, poolSupply, collateralSupply, 0, 0, owner, 0);
        }
    }
    
    /// - RESTRICTED ERC20 - ///
    
    function approve(address to, uint256 amount) external returns (bool) {
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
        if (block.timestamp >= timeRestrictionEnds) {timeRestricted = false;} // remove time restriction flag if ended - this saves gas in transfer checks and makes timing trustless
    }
    
    function updateWhitelist(address account, bool approved) external {
        require(msg.sender == owner, "!owner");
        whitelisted[account] = approved;
    }
}

/// @notice Factory for Uchi Token creation.
contract UchiTokenFactory {
    event DeployUchiToken(address indexed uchiToken);
    
    function deployUchiToken(
        address[] memory uchi,
        address collateral,
        string memory _name, 
        string memory _symbol, 
        uint256[] memory uchiSupply,
        uint256 collateralSupply,
        uint256 poolSupply,
        uint256 _timeRestrictionEnds
    ) external payable returns (UchiToken uchiToken) {
        bytes32 bytecodeHash = keccak256(type(UchiToken).creationCode);
        bytes32 data = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), msg.sender, bytecodeHash)
        );
        address preview = address(bytes20(data << 96));
        
        if (collateral == address(0)) {
            (bool success, ) = preview.call{value: msg.value}("");
            require(success, "!ethCall");
        } else {
            IERC20FWD(collateral).transferFrom(msg.sender, preview, collateralSupply);
        }
        
        uchiToken = new UchiToken(
            uchi,
            collateral,
            _name, 
            _symbol, 
            uchiSupply,
            collateralSupply,
            poolSupply,
            _timeRestrictionEnds);
        
        emit DeployUchiToken(address(uchiToken));
    }
}
