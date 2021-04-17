/// SPDX-License-Identifier: GPL-3.0-or-later
/*
 ▄         ▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄         ▄  ▄▄▄▄▄▄▄▄▄▄▄ 
▐░▌       ▐░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░░░░░░░░░░░▌
▐░▌       ▐░▌▐░█▀▀▀▀▀▀▀▀▀ ▐░▌       ▐░▌ ▀▀▀▀█░█▀▀▀▀ 
▐░▌       ▐░▌▐░▌          ▐░▌       ▐░▌     ▐░▌     
▐░▌       ▐░▌▐░▌          ▐░█▄▄▄▄▄▄▄█░▌     ▐░▌     
▐░▌       ▐░▌▐░▌          ▐░░░░░░░░░░░▌     ▐░▌     
▐░▌       ▐░▌▐░▌          ▐░█▀▀▀▀▀▀▀█░▌     ▐░▌     
▐░▌       ▐░▌▐░▌          ▐░▌       ▐░▌     ▐░▌     
▐░█▄▄▄▄▄▄▄█░▌▐░█▄▄▄▄▄▄▄▄▄ ▐░▌       ▐░▌ ▄▄▄▄█░█▄▄▄▄ 
▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░░░░░░░░░░░▌
 ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀  ▀▀▀▀▀▀▀▀▀▀▀ */
pragma solidity 0.8.3;
// File @boringcrypto/boring-solidity/contracts/BoringBatchable.sol@v1.2.0
/// License-Identifier: MIT
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
    /// @return successes An array indicating the success of a call, mapped one-to-one to `calls`.
    /// @return results An array with the returned data of each function call, mapped one-to-one to `calls`.
    // F1: External is ok here because this is the batch function, adding it to a batch makes no sense
    // F2: Calls in the batch may be payable, delegatecall operates in the same context, so each call in the batch has access to msg.value
    // C3: The length of the loop is fully under user control, so can't be exploited
    // C7: Delegatecall is only used on the same contract, so it's safe
    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns (bool[] memory successes, bytes[] memory results) {
        successes = new bool[](calls.length);
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, _getRevertMsg(result));
            successes[i] = success;
            results[i] = result;
        }
    }
}

/// @notice Interface for SushiSwap pair creation and ETH liquidity provision.
interface ISushiSwapLaunch {
    function approve(address spender, uint256 amount) external returns (bool); 
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

/// @notice Interface for UchiToken to import factory `masterUchi` list restrictions.
interface IMochi {
    function masterUchi(address account) external view returns (bool);
}

/// @notice Simple restricted ERC20 token with SushiSwap launch and minimal governance.
contract UchiToken is BaseBoringBatchable {
    ISushiSwapLaunch constant private sushiSwapFactory = ISushiSwapLaunch(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
    address constant private sushiSwapRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address constant private wETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C; 
    
    IMochi immutable private deployer;
    address public governance;
    address public sushiPair;
    string public name;
    string public symbol;
    uint8 constant public decimals = 18;
    uint256 public totalSupply;
    uint256 immutable public totalSupplyCap;
    uint256 immutable public timeRestrictionEnds; 
    bool public timeRestricted;
    bool public mochiRestricted;
    bool public uchiRestricted;
    
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public exempt;
    mapping(address => bool) public uchi;
    
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    
    constructor(
        address[] memory _uchi, // initial whitelist array of accounts
        string memory _name, // erc20-formatted UchiToken name
        string memory _symbol, // erc20-formatted UchiToken symbol
        uint256 _timeRestrictionEnds, // unix time for transfer restrictions to lift
        uint256 _totalSupplyCap, // supply cap for UchiToken mint
        uint256 pairDistro, // UchiToken amount supplied to `sushiPair`
        uint256[] memory uchiDistro, // UchiToken amount minted to `uchi`
        bool _mochiRestricted // if 'true', UchiToken imports `deployer` `masterUchi` list
    ) {
        for (uint256 i = 0; i < _uchi.length; i++) {
            balanceOf[_uchi[i]] = uchiDistro[i];
            totalSupply += uchiDistro[i];
            uchi[_uchi[i]] = true;
            emit Transfer(address(0), _uchi[i], uchiDistro[i]);
        }
        deployer = IMochi(msg.sender);
        governance = _uchi[0]; // first `uchi` is `governance`
        name = _name;
        symbol = _symbol;
        totalSupplyCap = _totalSupplyCap;
        timeRestrictionEnds = _timeRestrictionEnds;
        timeRestricted = true;
        mochiRestricted = _mochiRestricted;
        uchiRestricted = true;
        sushiPair = sushiSwapFactory.createPair(address(this), wETH);
        exempt[sushiSwapRouter] = true;
        exempt[sushiPair] = true;
        exempt[msg.sender] = true;
        balanceOf[msg.sender] = pairDistro;
        balanceOf[address(this)] = type(uint256).max; // max local balance denies transfers to this contract via overflow check (+saves gas)
        totalSupply += pairDistro;
    }

    /// - RESTRICTED ERC20 - ///
    function approve(address to, uint256 amount) public returns (bool) {
        allowance[msg.sender][to] = amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        if (!exempt[msg.sender] && timeRestricted) {require(block.timestamp >= timeRestrictionEnds, "!time/exempt");} 
        if (!exempt[msg.sender] && uchiRestricted) {require(uchi[msg.sender] && uchi[to], "!uchi/exempt");}
        if (mochiRestricted) {require(deployer.masterUchi(msg.sender) && deployer.masterUchi(to), "!uchi/exempt");}
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (!exempt[msg.sender] && timeRestricted) {require(block.timestamp >= timeRestrictionEnds, "!time/exempt");} 
        if (!exempt[msg.sender] && uchiRestricted) {require(uchi[msg.sender] && uchi[to], "!uchi/exempt");}
        if (mochiRestricted) {require(deployer.masterUchi(from) && deployer.masterUchi(to), "!uchi/exempt");}
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    /// - GOVERNANCE - ///
    modifier onlyGovernance {
        require(msg.sender == governance, "!governance");
        _;
    }
    
    function mint(address to, uint256 amount) external {
        require(totalSupply + amount <= totalSupplyCap, "capped"); 
        balanceOf[to] += amount; 
        totalSupply += amount; 
        emit Transfer(address(0), to, amount); 
    }
    
    function updateExempt(address[] calldata account, bool[] calldata approved) external onlyGovernance {
        for (uint256 i = 0; i < account.length; i++) {
            uchi[account[i]] = approved[i];
        }
    }
    
    function updateUchi(address[] calldata account, bool[] calldata approved) external onlyGovernance {
        for (uint256 i = 0; i < account.length; i++) {
            uchi[account[i]] = approved[i];
        }
    }
    
    function updateGovernance(address _governance, bool _uchiRestricted, bool _mochiRestricted) external onlyGovernance {
        governance = _governance;
        uchiRestricted = _uchiRestricted;
        mochiRestricted = _mochiRestricted;
        if (block.timestamp >= timeRestrictionEnds) {timeRestricted = false;} // remove time restriction flag if ended
    }
}

/// @notice Factory for UchiToken creation.
contract UchiTokenFactory is BaseBoringBatchable {
    address public uchiDAO = msg.sender;
    ISushiSwapLaunch constant private sushiSwapRouter = ISushiSwapLaunch(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    address immutable public temp = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // fixed template for UchiToken using eip-1167 proxy pattern
    
    mapping(address => bool) public masterUchi;
    event DeployUchiToken(address indexed uchiToken);
    
    function deployUchiToken(
        address[] calldata uchi, // initial whitelist array of accounts
        string calldata _name, // erc20-formatted UchiToken name
        string calldata _symbol, // erc20-formatted UchiToken symbol
        uint256 _timeRestrictionEnds, // unix time for transfer restrictions to lift
        uint256 totalSupplyCap, // supply cap for UchiToken mint
        uint256 pairDistro, // UchiToken amount supplied to `sushiPair`
        uint256[] calldata uchiDistro, // UchiToken amount minted to `uchi`
        bool _mochiRestricted // if true, UchiToken imports `masterUchi` list
    ) external payable returns (UchiToken uchiToken) {
        uchiToken = new UchiToken(
            uchi,
            _name, 
            _symbol,
            _timeRestrictionEnds,
            totalSupplyCap,
            pairDistro,
            uchiDistro,
            _mochiRestricted);
        uchiToken.approve(address(sushiSwapRouter), pairDistro);
        initMarket(address(uchiToken), pairDistro, uchi[0]);
        emit DeployUchiToken(address(uchiToken));
    }
    
    function initMarket(address uchiToken, uint256 uchiTokenToPair, address governance) private {
        sushiSwapRouter.addLiquidityETH{value: msg.value}(uchiToken, uchiTokenToPair, 0, 0, governance, block.timestamp+120);
    }
    
    /// - GOVERNANCE - ///
    function updateMasterUchi(address[] calldata account, bool[] calldata approved) external {
        require(msg.sender == uchiDAO, "!uchiDAO");
        for (uint256 i = 0; i < account.length; i++) {
            masterUchi[account[i]] = approved[i];
        }
    }
    
    function transferGovernance(address _uchiDAO) external {
        require(msg.sender == uchiDAO, "!uchiDAO");
        uchiDAO = _uchiDAO;
    }
}
