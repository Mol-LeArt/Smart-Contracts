pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
/// SPDX-License-Identifier: GPL-3.0-or-later

library SafeMath { // arithmetic wrapper for unit under/overflow check
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

library Utilities {
	// concat two bytes objects
    function concat(bytes memory a, bytes memory b)
            internal pure returns (bytes memory) {
        return abi.encodePacked(a, b);
    }

    // convert address to bytes
    function toBytes(address x) internal pure returns (bytes memory b) {
		b = new bytes(20);

		for (uint i = 0; i < 20; i++)
			b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
	}

	// convert uint256 to bytes
	function toBytes(uint256 x) internal pure returns (bytes memory b) {
    	b = new bytes(32);
    	assembly { mstore(add(b, 32), x) }
	}
}

contract GAMMA { // Γ - mv - NFT - mkt - γ
    address payable public dao = 0x057e820D740D5AAaFfa3c6De08C5c98d990dB00d;
    uint256 public constant GAMMA_MAX = 5772156649015328606065120900824024310421;
    uint256 public totalSupply;
    string public name = "GAMMA";
    string public symbol = "GAMMA";
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => uint256) public tokenByIndex;
    mapping(uint256 => string) public tokenURI;
    mapping(uint256 => Sale) public sale;
    mapping(bytes4 => bool) public supportsInterface; // eip-165 
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => mapping(uint256 => uint256)) public tokenOfOwnerByIndex;
    event Approval(address indexed approver, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event UpdateSale(uint256 indexed ethPrice, uint256 indexed tokenId, uint8 forSale);
    struct Sale {
        uint256 ethPrice;
        uint8 forSale;
    }
    constructor () public {
        supportsInterface[0x80ac58cd] = true; // ERC721 
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
    }
    function approve(address spender, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/operator");
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId); 
    }
    function mint(uint256 ethPrice, string calldata _tokenURI, uint8 forSale) external { 
        totalSupply++;
        require(totalSupply <= GAMMA_MAX, "maxed");
        uint256 tokenId = totalSupply;
        balanceOf[msg.sender]++;
        ownerOf[tokenId] = msg.sender;
        tokenByIndex[tokenId - 1] = tokenId;
        tokenURI[tokenId] = _tokenURI;
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        tokenOfOwnerByIndex[msg.sender][tokenId - 1] = tokenId;
        emit Transfer(address(0), msg.sender, tokenId); 
        emit UpdateSale(ethPrice, tokenId, forSale);
    }
    function purchase(uint256 tokenId) payable external {
        require(msg.value == sale[tokenId].ethPrice, "!ethPrice");
        require(sale[tokenId].forSale == 1, "!forSale");
        address owner = ownerOf[tokenId];
        (bool success, ) = owner.call{value: msg.value}("");
        require(success, "!transfer");
        _transfer(owner, msg.sender, tokenId);
    }
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    function _transfer(address from, address to, uint256 tokenId) internal {
        balanceOf[from]--; 
        balanceOf[to]++; 
        getApproved[tokenId] = address(0);
        ownerOf[tokenId] = to;
        sale[tokenId].forSale = 0;
        tokenOfOwnerByIndex[from][tokenId - 1] = 0;
        tokenOfOwnerByIndex[to][tokenId - 1] = tokenId;
        emit Transfer(from, to, tokenId); 
    }
    function transfer(address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId], "!owner");
        _transfer(msg.sender, to, tokenId);
    }
    function transferBatch(address[] calldata to, uint256[] calldata tokenId) external {
        require(to.length == tokenId.length, "!to/tokenId");
        for (uint256 i = 0; i < to.length; i++) {
            require(msg.sender == ownerOf[tokenId[i]], "!owner");
            _transfer(msg.sender, to[i], tokenId[i]);
        }
    }
    function transferFrom(address from, address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || getApproved[tokenId] == msg.sender || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/spender/operator");
        _transfer(from, to, tokenId);
    }
    function updateDao(address payable _dao) external {
        require(msg.sender == dao, "!dao");
        dao = _dao;
    }
    function updateSale(uint256 ethPrice, uint256 tokenId, uint8 forSale) payable external {
        require(msg.sender == ownerOf[tokenId], "!owner");
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        (bool success, ) = dao.call{value: msg.value}("");
        require(success, "!transfer");
        emit UpdateSale(ethPrice, tokenId, forSale);
    }
}

contract LiteToken { // minimal viable erc20 token with common extensions, such as burn, cap, mint, pauseable, admin functions
    address public owner;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public totalSupplyCap;
    bool public transferable; 
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;
    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _owner, uint256 _initialSupply, uint256 _totalSupplyCap, bool _transferable) public {require(_initialSupply <= _totalSupplyCap, "capped");
        name = _name; symbol = _symbol; decimals = _decimals; owner = _owner; totalSupply = _initialSupply; totalSupplyCap = _totalSupplyCap; transferable = _transferable; balanceOf[owner] = totalSupply; emit Transfer(address(0), owner, totalSupply);}
    function approve(address spender, uint256 amount) external returns (bool) {require(amount == 0 || allowance[msg.sender][spender] == 0); allowance[msg.sender][spender] = amount; emit Approval(msg.sender, spender, amount); return true;}
    function burn(uint256 amount) external {balanceOf[msg.sender] = balanceOf[msg.sender] - amount; totalSupply = totalSupply - amount; emit Transfer(msg.sender, address(0), amount);}
    function mint(address recipient, uint256 amount) external {require(msg.sender == owner, "!owner"); require(totalSupply + amount <= totalSupplyCap, "capped"); balanceOf[recipient] = balanceOf[recipient] + amount; totalSupply = totalSupply + amount; emit Transfer(address(0), recipient, amount);}
    function transfer(address recipient, uint256 amount) external returns (bool) {require(transferable == true); balanceOf[msg.sender] = balanceOf[msg.sender] - amount; balanceOf[recipient] = balanceOf[recipient] + amount; emit Transfer(msg.sender, recipient, amount); return true;}
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {require(transferable == true); balanceOf[sender] = balanceOf[sender] - amount; balanceOf[recipient] = balanceOf[recipient] + amount; allowance[sender][msg.sender] = allowance[sender][msg.sender] - amount; emit Transfer(sender, recipient, amount); return true;}
    function transferOwner(address _owner) external {require(msg.sender == owner, "!owner"); owner = _owner;}
    function updateTransferability(bool _transferable) external {require(msg.sender == owner, "!owner"); transferable = _transferable;}
}

contract MolVault {
    using SafeMath for uint256;
    address vault = address(this);
    address payable[] public owners;
    address payable[] public whitelist;
    address payable[] public newOwners;
    address payable public bidder;
    uint8 public numConfirmationsRequired;
    uint8 public numWithdrawalConfirmations;
    uint8 public numSaleConfirmations;
    uint256 public bid = 0;
    uint256 public gammaSupply = 0;
    uint256 public fundingGoal;
    uint256 public fundingGoalPerc = 100;
    uint256 public lockPeriod;
    uint256 public lockStartTime;
    bytes[] public depositTokens;
    
    GAMMA public gamma = new GAMMA();
    
    // Vault Shares
    LiteToken vaultShares;
    uint256 public airdrop = 100000000000000000000;
    uint8 public didMintShares = 0;
    address payable[] public fundingCollectors;
    
    struct Sale {
        address sender;
        uint8 forSale; // 1 = sale active, 0 = sale inactive
        uint256 ethPrice;
        uint256 tokenPrice;
    }
    
    mapping (bytes => bool) public NFTs;
	mapping (bytes => Sale) public sale;
    mapping (address => bool) public isOwner;
    mapping (address => bool) public isWhitelisted;
    mapping (address => bool) public withdrawalConfirmed;
    mapping (address => bool) public saleConfirmed;
    mapping (address => uint) public fundingCollectorPerc;

    constructor(address payable[] memory _owners, uint8 _numConfirmationsRequired, string memory _name, string memory _symbol, uint256 _fundingGoal, uint256 _lockPeriod) public {
        require(_owners.length > 0, "owners required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "invalid number of required confirmations");

        for (uint i = 0; i < _owners.length; i++) {
            address payable owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
            
            isWhitelisted[owner] = true;
            whitelist.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
        fundingGoal = _fundingGoal;
        lockPeriod = _lockPeriod;
        vaultShares = new LiteToken(_name, _symbol, 18, vault, 0, 1000000000000000000000000, false);
    }
    
    modifier onlyOwners() {
        require(isOwner[msg.sender], "!owner");
        _;
    }
    
    modifier onlyWhitelisted() {
        require(isWhitelisted[msg.sender], "!whitelisted");
        _;
    }
    
    function mint(uint256 _ethPrice, uint256 _tokenPrice, string memory _tokenURI, uint8 _forSale) public onlyWhitelisted{
        gammaSupply++;
        gamma.mint(_ethPrice, _tokenURI, _forSale);
        bytes memory tokenKey = getTokenKey(address(gamma), gammaSupply);
        NFTs[tokenKey] = true;
        sale[tokenKey].sender = msg.sender;
        sale[tokenKey].ethPrice = _ethPrice;
        sale[tokenKey].tokenPrice = _tokenPrice;
        sale[tokenKey].forSale = _forSale;
        vaultShares.mint(msg.sender, airdrop.mul(2)); 
    }
    
    function deposit(
        address _tokenAddress, 
        uint256 _tokenId, 
        uint256 _ethPrice,
        uint256 _tokenPrice, 
        uint8 _forSale) 
        public onlyWhitelisted {
		require(IERC721(_tokenAddress).ownerOf(_tokenId) == msg.sender, "!owner");
        bytes memory tokenKey = getTokenKey(_tokenAddress, _tokenId);
        
        // Deposit NFT
        depositTokens.push(tokenKey);
        NFTs[tokenKey] = true;
        IERC721(_tokenAddress).transferFrom(msg.sender, vault, _tokenId);
    
        // Set sale status
        sale[tokenKey].sender = msg.sender;
        sale[tokenKey].ethPrice = _ethPrice;
        sale[tokenKey].tokenPrice = _tokenPrice;
        sale[tokenKey].forSale = _forSale;  
	}
    
    function distributeFeeToFundingCollectors(uint256 fee) private {
        for (uint i = 0; i < fundingCollectors.length; i++) {
            uint split = (fundingCollectorPerc[fundingCollectors[i]].mul(fee)).div(100);
            (bool success, ) = fundingCollectors[i].call{value: split}("");
            require(success, "!transfer");
        }
    }
    
    function distributeFeeToWhitelist(uint256 fee) private {
        for (uint i = 0; i < whitelist.length; i++) {
            uint split = fee.mul(100).div(7);
            (bool success, ) = whitelist[i].call{value: split}("");
            require(success, "!transfer");
        }
    }
    
    function purchase(address _tokenAddress, uint256 _tokenId) public payable {
        bytes memory tokenKey = getTokenKey(_tokenAddress, _tokenId);
        require(sale[tokenKey].forSale == 1, "!sale");
        require(sale[tokenKey].sender != msg.sender, 'Sender cannot buy!');
        require(!isOwner[msg.sender], "Owners cannot buy!");
        
        uint256 feeToFundingCollector = sale[tokenKey].ethPrice.mul(5).div(1000);
        uint256 feeToWhitelist = sale[tokenKey].ethPrice.mul(5).div(1000);
        require((sale[tokenKey].ethPrice + feeToFundingCollector + feeToWhitelist) == msg.value, "!price");
        
        if (fundingGoalPerc > 0) {
            // check if fundingCollector 
            if (fundingCollectorPerc[msg.sender] == 0) {
               fundingCollectors.push(msg.sender); 
               uint perc = msg.value.mul(100).div(fundingGoal); 
            
               if (perc > fundingGoalPerc) {
                   fundingCollectorPerc[msg.sender] = fundingGoalPerc;
                   fundingGoalPerc = 0;
               } else {
                   fundingCollectorPerc[msg.sender] = perc;
                   fundingGoalPerc = fundingGoalPerc - perc;
               }
            }
            (bool success, ) = vault.call{value: sale[tokenKey].ethPrice}("");
            require(success, "!transfer");
        } else {
            if (didMintShares == 0) {
                lockStartTime = block.timestamp;
                didMintShares = 1;
            }

            (bool success, ) = vault.call{value: sale[tokenKey].ethPrice}("");
            require(success, "!transfer");
            
            distributeFeeToFundingCollectors(feeToFundingCollector);
            distributeFeeToWhitelist(feeToWhitelist);
            vaultShares.mint(msg.sender, airdrop);
        }
        
        IERC721(_tokenAddress).transferFrom(vault, msg.sender, _tokenId);
        sale[tokenKey].forSale = 0;
        NFTs[tokenKey] = false;
    }
    
    function tokenPurchase(address _tokenAddress, uint256 _tokenId) public payable {
        bytes memory tokenKey = getTokenKey(_tokenAddress, _tokenId);
        require(sale[tokenKey].forSale == 1, "!sale");
        require(vaultShares.balanceOf(msg.sender) >= sale[tokenKey].tokenPrice, "!price");
        require(!isOwner[msg.sender], "Owners cannot buy!");

        vaultShares.updateTransferability(true);
        vaultShares.transferFrom(msg.sender, vault, sale[tokenKey].tokenPrice); 
        vaultShares.updateTransferability(false);
        
        IERC721(_tokenAddress).transferFrom(vault, msg.sender, _tokenId);
        sale[tokenKey].forSale == 0;
        NFTs[tokenKey] = false;
    }
    
    function updateSale(address _tokenAddress, uint256 _tokenId, uint256 _ethPrice, uint256 _tokenPrice, uint8 _forSale) public {
        bytes memory tokenKey = getTokenKey(_tokenAddress, _tokenId);
        require(sale[tokenKey].sender == msg.sender, "!sender");
        sale[tokenKey].ethPrice = _ethPrice;
        sale[tokenKey].tokenPrice = _tokenPrice;
        sale[tokenKey].forSale = _forSale;  
    }
    
    function confirmSale() public onlyOwners {
        require(!saleConfirmed[msg.sender], 'Msg.sender already confirmed vault sale!');
	    numSaleConfirmations++;
	    saleConfirmed[msg.sender] = true;
	}
	
	function revokeSale() public onlyOwners {
        require(saleConfirmed[msg.sender], 'Msg.sender did not confirm vault sale!');
	    numSaleConfirmations--;
	    saleConfirmed[msg.sender] = false;
	}
    
    function bidVault(address payable[] memory _newOwners) public payable {
        require(msg.value > bid, "You must bid higher than the existing bid!"); // tricky 
        require(_newOwners.length > 0, "There must be at least one new owner!");
        
        (bool success, ) = bidder.call{value: bid}("");
        require(success, "!transfer");
        
        bidder = msg.sender;
        bid = msg.value;
        newOwners = _newOwners;
    }
    
    function sellVault() public onlyOwners {
	    require(numSaleConfirmations >= numConfirmationsRequired, "!numConfirmationsRequired");
        uint256 cut = (bid / owners.length);

        // Reset sale confirmations
        for (uint8 i = 0; i < owners.length; i++) {
	        (bool success, ) = owners[i].call{value: cut}("");
            require(success, "!transfer");
            saleConfirmed[owners[i]] = false;
            numSaleConfirmations = 0;
	    }
        
        // Clear ownership
        for (uint8 i = 0; i < owners.length; i++) {
            isOwner[owners[i]] = false;
        }
        
        // Transition ownership 
        owners = newOwners;
        
        for (uint8 i = 0; i < owners.length; i++) {
            isOwner[owners[i]] = true;
        }
        
        // Clear whitelist
        for (uint8 i = 0; i < whitelist.length; i++) {
            isWhitelisted[whitelist[i]] = false;
        }
        
        // Reset bid and bidder
        bidder = address(0);
        bid = 0;
    }
	
	function confirmWithdrawal() public onlyOwners {
	    // might require didMintShares != 0
	    require(!withdrawalConfirmed[msg.sender], 'Withdrawal already confirmed!');
	    numWithdrawalConfirmations++;
	    withdrawalConfirmed[msg.sender] = true;
	}
	
	function revokeWithdrawal() public onlyOwners { 
	    require(withdrawalConfirmed[msg.sender], 'Withdrawal not confirmed!');
	    numWithdrawalConfirmations--;
	    withdrawalConfirmed[msg.sender] = false;
	}
	
	function executeWithdrawal() public onlyOwners {
	    require(now > lockStartTime + lockPeriod, "Time-locked");
	    require(didMintShares == 1, "Vault shares not minted!");
	    require(numWithdrawalConfirmations >= numConfirmationsRequired, "!numConfirmationsRequired");
	    
        uint256 cut = (address(this).balance / owners.length);

	    for (uint8 i = 0; i < owners.length; i++){
	        (bool success, ) = owners[i].call{value: cut}("");
            require(success, "!transfer");
            
            withdrawalConfirmed[owners[i]] = false;
            numWithdrawalConfirmations = 0;
	    }
	}
	
	function addToWhitelist(address payable[] memory _address) public onlyOwners {
	    for (uint8 i = 0; i < _address.length; i++) {
	        address payable newAddress = _address[i];
	        require(!isWhitelisted[newAddress], "Already whitelisted!");
	        isWhitelisted[newAddress] = true;
	        whitelist.push(newAddress);
	    }
	}
	
	function removeFromWhitelist(address[] memory _address) public onlyOwners {
	    for (uint8 i = 0; i < _address.length; i++) {
	        address newAddress = _address[i];
	        require(isWhitelisted[newAddress], "No address to remove!");
	        isWhitelisted[newAddress] = false;
	        
	        for (uint8 j = 0; j < whitelist.length; j++) {
	            if (newAddress == whitelist[j]) {
	                whitelist[j] = address(0);
	            }
	        }
	    }
	}
	
	function getWhitelist() public view returns (address[] memory) {
	    address[] memory roster = new address[](whitelist.length);
	    for (uint i = 0; i < whitelist.length; i++) {
	        roster[i] = whitelist[i];
	    }    
	    return roster;
	}
	
	function getFundingColectors() public view returns (address[] memory) {
	    address[] memory funders = new address[](fundingCollectors.length);
	    for (uint i = 0; i < fundingCollectors.length; i++) {
	        funders[i] = fundingCollectors[i];
	    }
	    return funders;
	}
	
	function getNewOwners() public view returns (address[] memory) {
	    address[] memory nOwners = new address[](newOwners.length);
	    for (uint i = 0; i < newOwners.length; i++) {
	        nOwners[i] = newOwners[i];
	    }
	    return nOwners;
	}
	
	function getDepositTokens() public view returns (bytes[] memory) {
	    bytes[] memory tokens = new bytes[](depositTokens.length);
	    for (uint i = 0; i < depositTokens.length; i++) {
	        tokens[i] = depositTokens[i];
	    }    
	    return tokens;
	}
	
	function removeGamma(address _tokenAddress, uint256 _tokenId) public onlyOwners {
        IERC721(_tokenAddress).transferFrom(vault, msg.sender, _tokenId);
	}
	
	function updateAirdrop(uint256 amount) public onlyOwners {
	    airdrop = amount;
	}
	
    // Function for getting the document key for a given NFT address + tokenId
	function getTokenKey(address tokenAddress, uint256 tokenId) public pure returns (bytes memory) {
		return Utilities.concat(Utilities.toBytes(tokenAddress), Utilities.toBytes(tokenId));
	}
	
    receive() external payable {  require(msg.data.length ==0); }
}
