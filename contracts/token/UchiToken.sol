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

/// @notice Simple restricted ERC20 token with SushiSwap launch and minimal governance.
contract UchiToken is BaseBoringBatchable {
    ISushiSwapLaunch constant private sushiSwapFactory = ISushiSwapLaunch(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
    address constant private sushiSwapRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address constant private wETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C; 
    
    address public governance;
    address public sushiPair;
    string public name;
    string public symbol;
    uint8 constant public decimals = 18;
    uint256 public totalSupply;
    uint256 immutable public totalSupplyCap;
    uint256 immutable public timeRestrictionEnds; 
    
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public exempt;
    mapping(address => bool) public uchi;
    
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event UpdateExempt(address indexed account, bool approved);
    event UpdateUchi(address indexed account, bool approved);
    
    constructor(
        address[] memory _uchi, // initial whitelist array of accounts
        string memory _name, // erc20-formatted UchiToken 'name'
        string memory _symbol, // erc20-formatted UchiToken 'symbol'
        uint256 _timeRestrictionEnds, // unix time for transfer restrictions to lift (if `0`, no restriction)
        uint256 _totalSupplyCap, // supply cap for UchiToken mint
        uint256 pairDistro, // UchiToken amount minted for `sushiPair`
        uint256[] memory uchiDistro // UchiToken amount minted to `uchi`
    ){
        for(uint256 i = 0; i < _uchi.length; i++){
            balanceOf[_uchi[i]] = uchiDistro[i];
            totalSupply += uchiDistro[i];
            uchi[_uchi[i]] = true;
            emit Transfer(address(0), _uchi[i], uchiDistro[i]);}
        governance = _uchi[0]; // first `uchi` is `governance`
        sushiPair = sushiSwapFactory.createPair(address(this), wETH);
        name = _name;
        symbol = _symbol;
        totalSupplyCap = _totalSupplyCap;
        timeRestrictionEnds = _timeRestrictionEnds;
        exempt[msg.sender] = true;
        exempt[sushiSwapRouter] = true;
        exempt[sushiPair] = true;
        balanceOf[msg.sender] = pairDistro; 
        balanceOf[address(this)] = type(uint256).max; // max local balance blocks sends to UchiToken via overflow check (+saves gas)
        require(totalSupply + pairDistro <= _totalSupplyCap, "capped"); 
        totalSupply += pairDistro;
        emit Transfer(address(0), msg.sender, pairDistro);
    }

    /// - RESTRICTED ERC20 - ///
    function approve(address to, uint256 amount) external returns (bool) {
        allowance[msg.sender][to] = amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        if(!exempt[msg.sender] && !exempt[to]){
           require(block.timestamp >= timeRestrictionEnds, "!time/exempt"); 
           require(uchi[msg.sender] && uchi[to], "!uchi/exempt");}
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if(!exempt[from] && !exempt[to]){
           require(block.timestamp >= timeRestrictionEnds, "!time/exempt");
           require(uchi[from] && uchi[to], "!uchi/exempt");}
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
    
    function mint(address to, uint256 amount) external onlyGovernance {
        require(totalSupply + amount <= totalSupplyCap, "capped"); 
        balanceOf[to] += amount; 
        totalSupply += amount; 
        emit Transfer(address(0), to, amount); 
    }
    
    function transferGovernance(address _governance) external onlyGovernance {
        governance = _governance;
    }
    
    function updateExempt(address[] calldata account, bool[] calldata approved) external onlyGovernance {
        for(uint256 i = 0; i < account.length; i++){
            exempt[account[i]] = approved[i];
            emit UpdateExempt(account[i], approved[i]);
        }
    }
    
    function updateUchi(address[] calldata account, bool[] calldata approved) external onlyGovernance {
        for(uint256 i = 0; i < account.length; i++){
            uchi[account[i]] = approved[i];
            emit UpdateUchi(account[i], approved[i]);
        }
    }
}

/// @notice Factory for UchiToken creation.
contract UchiTokenFactory is BaseBoringBatchable {
    address public uchiDAO = msg.sender;
    ISushiSwapLaunch constant sushiSwapRouter = ISushiSwapLaunch(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    mapping(address => uint256) public uchiList;
    event DeployUchiToken(address indexed uchiToken);
    event UpdateUchiList(address indexed account, uint256 indexed list, string details);
    
    function deployUchiToken(
        address[] calldata _uchi, // initial whitelist array of accounts
        string calldata _name, // erc20-formatted UchiToken 'name'
        string calldata _symbol, // erc20-formatted UchiToken 'symbol'
        uint256 _timeRestrictionEnds, // unix time for transfer restrictions to lift (if `0`, no restriction)
        uint256 _totalSupplyCap, // supply cap for UchiToken mint
        uint256 pairDistro, // UchiToken amount minted for `sushiPair`
        uint256[] calldata uchiDistro, // UchiToken amount minted to `uchi`
        uint256 list // if not `0`, add a check to `uchi` against given `uchiList`
    ) external payable returns (UchiToken uchiToken) {
        if(list != 0){checkList(_uchi, list);}
        uchiToken = new UchiToken(
            _uchi,
            _name, 
            _symbol,
            _timeRestrictionEnds,
            _totalSupplyCap,
            pairDistro,
            uchiDistro);
        uchiToken.approve(address(sushiSwapRouter), pairDistro);
        initMarket(address(uchiToken), pairDistro, _uchi[0]);
        emit DeployUchiToken(address(uchiToken));
    }
    
    function checkList(address[] calldata uchi, uint256 list) private view { // deployment helper to avoid `stack too deep` error
        for(uint256 i = 0; i < uchi.length; i++){require(uchiList[uchi[i]] == list, "!listed");}
    }
    
    function initMarket(address uchiToken, uint256 pairDistro, address governance) private { // deployment helper to avoid `stack too deep` error
        sushiSwapRouter.addLiquidityETH{value: msg.value}(uchiToken, pairDistro, 0, 0, governance, 2533930386);
    }
    
    /// - GOVERNANCE - ///
    function updateUchiList(address[] calldata account, uint256[] calldata list, string calldata details) external { // `0` is default and delisting action
        require(msg.sender == uchiDAO, "!uchiDAO");
        for(uint256 i = 0; i < account.length; i++){uchiList[account[i]] = list[i]; emit UpdateUchiList(account[i], list[i], details);}
    }
    
    function transferGovernance(address _uchiDAO) external {
        require(msg.sender == uchiDAO, "!uchiDAO");
        uchiDAO = _uchiDAO;
    }
}
