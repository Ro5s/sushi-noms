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

/// @notice Whitelist ERC20 token with SushiSwap launch.
contract UchiToken {
    ISushiSwapLaunch constant sushiSwapFactory=ISushiSwapLaunch(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
    address constant sushiSwapRouter=0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address constant wETH=0xd0A1E359811322d97991E03f863a0C30C2cF029C; 
    address public governance;
    string public name;
    string public symbol;
    uint8 constant public decimals=18;
    uint256 public totalSupply;
    uint256 immutable public totalSupplyCap;
    bool public uchiRestricted;
    
    mapping(address=>mapping(address=>uint256)) public allowance;
    mapping(address=>uint256) public balanceOf;
    mapping(address=>bool) public uchi;
    
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event UpdateUchi(address indexed account, bool approved);
    
    constructor(
        address[] memory _uchi, // initial whitelist array of accounts
        string memory _name, // erc20-formatted UchiToken 'name'
        string memory _symbol, // erc20-formatted UchiToken 'symbol'
        uint256 _totalSupplyCap, // supply cap for UchiToken mint
        uint256 pairDistro, // UchiToken amount minted for `sushiPair`
        uint256[] memory uchiDistro, // UchiToken amount minted to `uchi`
        bool market // if 'true', launch pair and add ETH liquidity on SushiSwap via 'Factory'
    ){
        for(uint256 i=0;i<_uchi.length;i++){
            balanceOf[_uchi[i]]=uchiDistro[i];
            totalSupply+=uchiDistro[i];
            uchi[_uchi[i]]=true;
            emit Transfer(address(0), _uchi[i], uchiDistro[i]);}
        if(market){
            address sushiPair=sushiSwapFactory.createPair(address(this), wETH);
            uchi[msg.sender]=true;
            uchi[sushiSwapRouter]=true;
            uchi[sushiPair]=true;
            balanceOf[msg.sender]=pairDistro;
            totalSupply+=pairDistro;
            emit Transfer(address(0), msg.sender, pairDistro);}
        require(totalSupply<=_totalSupplyCap,"capped"); 
        governance=_uchi[0]; // first `uchi` is `governance`
        name=_name;
        symbol=_symbol;
        totalSupplyCap=_totalSupplyCap;
        uchiRestricted=true;
        balanceOf[address(this)]=type(uint256).max; // max local balance blocks sends to UchiToken via overflow check (+saves gas)
    }

    /// - RESTRICTED ERC20 - ///
    function approve(address to, uint256 amount) external returns (bool) {
        allowance[msg.sender][to]=amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        if(uchiRestricted){require(uchi[msg.sender]&&uchi[to],"!uchi");}
        balanceOf[msg.sender]-=amount;
        balanceOf[to]+=amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if(uchiRestricted){require(uchi[from]&&uchi[to],"!uchi");}
        balanceOf[from]-=amount;
        balanceOf[to]+=amount;
        allowance[from][msg.sender]-=amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    /// - GOVERNANCE - ///
    modifier onlyGovernance {
        require(msg.sender==governance,"!governance");
        _;
    }
    
    function mint(address to, uint256 amount) external onlyGovernance {
        require(totalSupply+amount<=totalSupplyCap,"capped"); 
        balanceOf[to]+=amount; 
        totalSupply+=amount; 
        emit Transfer(address(0), to, amount); 
    }
    
    function transferGovernance(address _governance) external onlyGovernance {
        governance=_governance;
    }

    function updateUchi(address[] calldata account, bool[] calldata approved) external onlyGovernance {
        for(uint256 i=0;i<account.length;i++){
            uchi[account[i]]=approved[i];
            emit UpdateUchi(account[i], approved[i]);
        }
    }

    function updateUchiRestriction(bool _uchiRestricted) external onlyGovernance {
        uchiRestricted=_uchiRestricted;
    }
}

/// @notice Factory for UchiToken deployment.
contract UchiTokenFactory {
    ISushiSwapLaunch constant sushiSwapRouter=ISushiSwapLaunch(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    address public uchiDAO=msg.sender;

    mapping(address=>uint256) public uchiList;
    
    event DeployUchiToken(address indexed uchiToken);
    event UpdateUchiList(address indexed account, uint256 indexed list, string details);
    
    function deployUchiToken(
        address[] calldata _uchi, // initial whitelist array of accounts
        string calldata _name, // erc20-formatted UchiToken 'name'
        string calldata _symbol, // erc20-formatted UchiToken 'symbol'
        uint256 _totalSupplyCap, // supply cap for UchiToken mint
        uint256 pairDistro, // UchiToken amount minted for `sushiPair`
        uint256[] calldata uchiDistro, // UchiToken amount minted to `uchi`
        uint256 list, // if not '0', add check to `uchi` against given `uchiList`
        bool market // if 'true', launch pair and add ETH liquidity on SushiSwap
    ) external payable returns (UchiToken uchiToken) {
        if(list!=0){checkList(_uchi, list);}
        uchiToken=new UchiToken(
            _uchi,
            _name, 
            _symbol,
            _totalSupplyCap,
            pairDistro,
            uchiDistro,
            market);
        if(market){
            uchiToken.approve(address(sushiSwapRouter), pairDistro);
            initMarket(address(uchiToken), pairDistro, _uchi[0]);}
        emit DeployUchiToken(address(uchiToken));
    }
    
    function checkList(address[] calldata _uchi, uint256 list) private view { // deployment helper to avoid `stack too deep` error
        for(uint256 i=0;i<_uchi.length;i++){require(uchiList[_uchi[i]]==list,"!listed");}
    }
    
    function initMarket(address uchiToken, uint256 pairDistro, address governance) private { // deployment helper to avoid `stack too deep` error
        sushiSwapRouter.addLiquidityETH{value: msg.value}(uchiToken, pairDistro, 0, 0, governance, 2533930386);
    }
    
    /// - GOVERNANCE - ///
    function updateUchiList(address[] calldata account, uint256[] calldata list, string calldata details) external { // `0` is default and delisting action
        require(msg.sender==uchiDAO,"!uchiDAO");
        for(uint256 i=0;i<account.length;i++){
            uchiList[account[i]]=list[i]; 
            emit UpdateUchiList(account[i], list[i], details);
        }
    }
    
    function transferGovernance(address _uchiDAO) external {
        require(msg.sender==uchiDAO,"!uchiDAO");
        uchiDAO=_uchiDAO;
    }
}
