pragma solidity 0.6.12;
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

library Utilities {
    function append(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}

contract Controller {
    GAMMA public gamma;
    address[] public minters;
    address[] public controllers;
    uint8[10] public confirmationCounts; // [consensus, withdraw, change controllers]

    mapping (uint8 => mapping (address => bool)) public isConfirmed;
    mapping (address => bool) public isController;
    mapping (address => bool) public isMinter;

    event Confirm(uint indexed _type, address indexed signer);
    event Revoke(uint indexed _type, address indexed signer);
    event Withdraw(uint indexed amount, address indexed signer);
    event ChangeController(address[] indexed _controllers, address indexed signer);
    event Royalties(uint royalties);
    event Fee(uint fee);
    event TokenTransfer(address to, uint tokenId);
    event ApprovedContract(address _contract);
    event Minters(address[] minters);
    
    constructor (
        string memory _tokenName, 
        string memory _tokenSymbol, 
        string memory _gRoyaltiesURI, 
        address[] memory _controllers,
        address[] memory _minters,
        uint8 consensusRequired
        ) public {
        require(_controllers.length != 0, 'Controller count is 0');
        require(consensusRequired != 0, 'Consensus count is 0');
        
        gamma = new GAMMA(_tokenName, _tokenSymbol, _gRoyaltiesURI);
        
        controllers = _controllers;
        for (uint i = 0; i < _controllers.length; i++) {
            isController[_controllers[i]] = true;
        }
        
        minters = _minters;
        for (uint i = 0; i < _minters.length; i++) {
            isMinter[_minters[i]] = true;
        }
        
        confirmationCounts[0] = consensusRequired;
    }
    
    modifier onlyControllers() {
        require(isController[msg.sender], '!controller');
        _;
    }
    
    modifier onlyMinters() {
        require(isMinter[msg.sender], '!minter');
        _;
    }
    
    function confirm(uint8 _type, address _signer) internal {
        require(!isConfirmed[_type][_signer], 'Msg.sender already confirmed vault sale!');
	    confirmationCounts[_type]++;
	    isConfirmed[_type][_signer] = true;
	    emit Confirm(_type, _signer);
	}
	
	function revoke(uint8 _type, address _signer) internal {
	    require(isConfirmed[_type][_signer], 'Msg.sender has not confirmed vault sale!');
	    confirmationCounts[_type]--;
	    isConfirmed[_type][_signer] = false;
	    emit Revoke(_type, _signer);
	}
	
	// ----- Gamma Functions
	function mint(
	    uint256 _ethPrice, 
        string calldata _tokenURI, 
        uint8 _forSale, 
        address _minter, 
        uint256 _split,
        address[] memory _collaborators,
        uint8[] memory _collaboratorsWeight
        ) external onlyMinters {
	    gamma.mint(
            _ethPrice, 
            _tokenURI, 
            _forSale, 
            _minter, 
            _split,
            _collaborators,
            _collaboratorsWeight);
	}
	
	// ----- MultiSig Functions 
	function confirmWithdraw(uint256 amount, address payable _address) external onlyControllers {
	    confirm(1, msg.sender);
	    
	    if (confirmationCounts[1] == confirmationCounts[0]) {
	        require(address(this).balance > amount, '!amount to withdraw');
	        (bool success, ) = _address.call{value: amount}("");
            require(success, "withdraw failed");
	    }
	    emit Withdraw(amount, msg.sender);
	}
	
	function revokeWithdraw() external onlyControllers {
	    revoke(1, msg.sender);
	}
	
	function confirmControllersChange(address[] memory _controllers) external onlyControllers {
	    confirm(2, msg.sender);
	    
	    if (confirmationCounts[2] == confirmationCounts[0]) {
	        
	        for (uint i = 0; i < controllers.length; i++){
	            isController[controllers[i]] = false;
	        }
	        
	        controllers = _controllers;
	        
	        for (uint i = 0; i < controllers.length; i++){
	            isController[controllers[i]] = true;
	        }	        
	        
	    }
	    emit ChangeController(_controllers, msg.sender);
	}
	
	function revokeControllersChange() external onlyControllers {
	    revoke(2, msg.sender);
	}
	
	// ----- Controller Management
	function updateConsensus(uint8 _consensusCount) external onlyControllers {
	    confirmationCounts[0] = _consensusCount;
	}
	
	function updateMinter(address[] memory _minters) external onlyControllers {
	    minters = _minters;
	    
	    for (uint i = 0; i < _minters.length; i++) {
            isMinter[_minters[i]] = true;
        }
	    emit Minters(minters);
	}
	
    function updateRoyalties(uint _royalties) external onlyControllers {
        gamma.updateRoyalties(_royalties);
        emit Royalties(_royalties);
    }

    function updateFee(uint _fee) external onlyControllers {
        gamma.updateFee(_fee);
        emit Fee(_fee);
    }
    
    function transferToken(address _to, uint256 _tokenId) external onlyControllers {
        gamma.transferToken(_to, _tokenId);
        emit TokenTransfer(_to, _tokenId);
    }

    // ----- Approve contract to transfer gamma
	function approveContract(address _contract) public onlyControllers {
	    gamma.setApprovalForAll(_contract, true);
	    emit ApprovedContract(_contract);
	}
	
	receive() external payable {  require(msg.data.length ==0); }
}

contract GAMMA {
    using SafeMath for uint256;
    address payable public controller;
    uint256 public constant GAMMA_MAX = 5772156649015328606065120900824024310421;
    uint256 public fee = 5;
    uint256 public royalties = 10;
    uint256 public totalSupply;
    string public gRoyaltiesURI;
    string public name;
    string public symbol;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(uint256 => address) public ownerOf;
    
    mapping(uint256 => uint256) public tokenByIndex;
    mapping(uint256 => string) public tokenURI;
    mapping(uint256 => Sale) public sale;
    mapping(bytes4 => bool) public supportsInterface; // eip-165 
    mapping(uint256 => address payable) public gRoyaltiesByTokenId; // gRoyaltiesByTokenId[tokenId]
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => mapping(uint256 => uint256)) public tokenOfOwnerByIndex;
    event Approval(address indexed approver, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed holder, address indexed operator, bool approved);
    event gRoyaltiesMinted(address indexed contractAddress);
    event UpdateController(address indexed controller);
    event UpdateFee(uint256 indexed fee);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event UpdateSale(uint8 forSale, uint256 indexed ethPrice, uint256 indexed tokenId);
    event Purchase(uint256 indexed tokenId, uint256 indexed ethPrice);
    event Mint(uint256 indexed tokenId, uint256 ethPrice, string tokenURI, uint8 forSale, address indexed minter, uint256 split, address[] _collaborators, uint8[] _collaboratorsWeight);
    struct Sale {
        uint256 ethPrice;
        uint8 forSale; // 0 = !sale, 1 = sale
        address minter;
        uint256 split;
        address[] collaborators;
        uint8[] collaboratorsWeight;
        uint8 didPrimary; // 0 = !primary, 1 = primary
    }
    constructor (string memory _name, string memory _symbol, string memory _gRoyaltiesURI) public {
        supportsInterface[0x80ac58cd] = true; // ERC721 
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
        name = _name;
        symbol = _symbol;
        controller = msg.sender;
        gRoyaltiesURI = _gRoyaltiesURI;
    }
    function approve(address spender, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/operator");
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId); 
    }
    function mint(
        uint256 _ethPrice, 
        string calldata _tokenURI, 
        uint8 _forSale, 
        address _minter, 
        uint256 _split,
        address[] memory _collaborators,
        uint8[] memory _collaboratorsWeight
        ) external onlyController { 
        totalSupply++;
        require(_forSale <= 1, "!forSale value");
        require(totalSupply <= GAMMA_MAX, "maxed");
        require(_collaborators.length == _collaboratorsWeight.length, "!collaborator/weight");
        uint256 tokenId = totalSupply;
        balanceOf[_minter]++;
        ownerOf[tokenId] = _minter;
        
        sale[tokenId].ethPrice = _ethPrice;
        sale[tokenId].forSale = _forSale;
        sale[tokenId].minter = _minter;
        sale[tokenId].split = _split;
        sale[tokenId].collaborators = _collaborators;
        sale[tokenId].collaboratorsWeight = _collaboratorsWeight;
        
        tokenByIndex[tokenId - 1] = tokenId;
        tokenOfOwnerByIndex[_minter][tokenId - 1] = tokenId;
        tokenURI[tokenId] = _tokenURI;
        
        // mint royalties token and transfer to artist
        gRoyalties g = new gRoyalties();
        g.mint(Utilities.append(name, " Royalties Token"), gRoyaltiesURI, _minter);
        gRoyaltiesByTokenId[tokenId] = address(g);
        
        emit gRoyaltiesMinted(address(g));
        emit Transfer(address(0), _minter, tokenId);
        emit Mint(tokenId, sale[tokenId].ethPrice, tokenURI[tokenId], sale[tokenId].forSale, sale[tokenId].minter, sale[tokenId].split, sale[tokenId].collaborators, sale[tokenId].collaboratorsWeight);
    }
    function distributeCollabSplit(uint256 _tokenId, uint256 _ethPrice) private {
        require(sale[_tokenId].collaborators.length == sale[_tokenId].collaboratorsWeight.length, "!collaborator/weight");
        uint256 totalPayout = _ethPrice.div(100);
        for (uint256 i = 0; i < sale[_tokenId].collaborators.length; i++) {
            uint256 eachPayout;
            eachPayout = totalPayout.mul(sale[_tokenId].collaboratorsWeight[i]);
            (bool success, ) = address(uint160(sale[_tokenId].collaborators[i])).call{value: eachPayout}("");
            require(success, "!primary collab split transfer");
        }
    }
    function purchase(uint256 tokenId) payable external {
        require(msg.value == sale[tokenId].ethPrice, "!ethPrice");
        require(msg.sender != ownerOf[tokenId], "owner"); 
        require(sale[tokenId].forSale == 1, "!forSale");
        if (sale[tokenId].didPrimary == 0) {
            // Tx fee
            uint256 payout = fee.mul(sale[tokenId].ethPrice).div(100);
            (bool success, ) = controller.call{value: payout}("");
            require(success, "!primary fee transfer");
            
            // Collab payout
            uint256 collabPayout = sale[tokenId].split.mul(sale[tokenId].ethPrice).div(100);
            distributeCollabSplit(tokenId, collabPayout);
            
            // Residual payout
            (success, ) = ownerOf[tokenId].call{value: sale[tokenId].ethPrice.sub(payout).sub(collabPayout)}("");
            require(success, "!primary residual transfer");
            sale[tokenId].didPrimary = 1;
        } else {
            // Royalties payout
            uint256 _royalties = sale[tokenId].ethPrice.mul(royalties).div(100);
            (bool success, ) = gRoyaltiesByTokenId[tokenId].call{value: _royalties}("");
            require(success, "!secondary transfer royalties from GAMMA to gRoyalties");
            
            // Residual payout
            (success, ) = ownerOf[tokenId].call{value: sale[tokenId].ethPrice.sub(_royalties)}("");
            require(success, "!secondary residual transfer");            
        }
        _transfer(ownerOf[tokenId], msg.sender, tokenId);
        
        emit Purchase(tokenId, sale[tokenId].ethPrice);
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
    function transferFrom(address from, address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || getApproved[tokenId] == msg.sender || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/spender/operator");
        _transfer(from, to, tokenId);
    }
    function updateSale(uint256 _ethPrice, uint256 _tokenId, uint8 _forSale) external {
        require(msg.sender == ownerOf[_tokenId], "!owner"); // Communal ownership
        sale[_tokenId].ethPrice = _ethPrice;
        sale[_tokenId].forSale = _forSale;
        emit UpdateSale(_forSale, _ethPrice, _tokenId);
    }
    function getSale(uint256 tokenId) public view returns (uint, uint, address, uint, address[] memory, uint8[] memory, uint) {
        return (
            sale[tokenId].ethPrice, 
            sale[tokenId].forSale, 
            sale[tokenId].minter,
            sale[tokenId].split,
            sale[tokenId].collaborators,
            sale[tokenId].collaboratorsWeight,
            sale[tokenId].didPrimary);
    }
    function getAllTokenURI() public view returns (string[] memory){
        string[] memory tokenURIs = new string[](totalSupply);
        for (uint i = 0; i < totalSupply; i++) {
            tokenURIs[i] = tokenURI[i.add(1)];
        }
        return tokenURIs;
    }

    /******************
    Controller Functions
    ******************/
    modifier onlyController () {
        require(msg.sender == controller, "!controller");
        _;
    }
    function transferToken(address _to, uint256 _tokenId) public onlyController {
        _transfer(ownerOf[_tokenId], _to, _tokenId);
    }
    function updateFee(uint256 _fee) public onlyController {
        fee = _fee;
        emit UpdateFee(fee);
    }
    function updateRoyalties(uint256 _royalties) public onlyController {
        royalties = _royalties;
    }
}

contract gRoyalties { // Γ - mv - NFT - mkt - γ
    uint256 public totalSupply = 1;
    string public name;
    string public symbol= "gRoyalties";
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
    event UpdateSale(uint256 indexed ethPrice, uint256 indexed tokenId, bool forSale);
    struct Sale {
        uint256 ethPrice;
        bool forSale;
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
    function mint(string calldata _name, string calldata _tokenURI, address minter) external { 
        name = _name;
        // use totalSupply as tokenId
        balanceOf[minter]++;
        ownerOf[totalSupply] = minter;
        tokenByIndex[totalSupply - 1] = totalSupply;
        tokenURI[totalSupply] = _tokenURI;
        tokenOfOwnerByIndex[minter][totalSupply - 1] = totalSupply;
        emit Transfer(address(0), minter, totalSupply); 
    }
    function purchase(uint256 tokenId) payable external {
        require(msg.value == sale[tokenId].ethPrice, "!ethPrice");
        require(sale[tokenId].forSale, "!forSale");
        (bool success, ) = ownerOf[tokenId].call{value: msg.value}("");
        require(success, "!transfer");
        _transfer(ownerOf[tokenId], msg.sender, tokenId);
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
        sale[tokenId].forSale = false;
        tokenOfOwnerByIndex[from][tokenId - 1] = 0;
        tokenOfOwnerByIndex[to][tokenId - 1] = tokenId;
        emit Transfer(from, to, tokenId); 
    }
    function transfer(address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId], "!owner");
        _transfer(msg.sender, to, tokenId);
    }
    function transferFrom(address from, address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || getApproved[tokenId] == msg.sender || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/spender/operator");
        _transfer(from, to, tokenId);
    }
    function updateSale(uint256 ethPrice, uint256 tokenId, bool forSale) payable external {
        require(msg.sender == ownerOf[tokenId], "!owner");
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        emit UpdateSale(ethPrice, tokenId, forSale);
    }
    function withdraw() payable public {
        require(msg.sender == ownerOf[totalSupply], "!owner");
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "!transfer");        
    }
    receive() external payable {  require(msg.data.length ==0); }
}
