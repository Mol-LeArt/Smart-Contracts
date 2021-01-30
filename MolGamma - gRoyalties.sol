/*
DEAR MSG.SENDER(S):

/ MolGamma is a project in beta.
// Please audit and use at your own risk.
/// There is also a DAO to join if you're curious.
//// This is code, don't construed this as legal advice or replacement for professional counsel.
///// STEAL THIS C0D3SL4W

~ presented by Mol LeArt ~
*/

pragma solidity 0.5.17;

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

contract MolGamma {
    using SafeMath for uint256;
    address payable public creator;
    address public mol = 0xF09631d7BA044bfe44bBFec22c0A362c7e9DCDd8;
    address payable public molBank = 0xF09631d7BA044bfe44bBFec22c0A362c7e9DCDd8;
    uint256 public constant GAMMA_MAX = 5772156649015328606065120900824024310421;
    uint256 public molFee = 5;
    uint256 public startingRoyalties = 10;
    uint256 public totalSupply;
    string public gRoyaltiesURI;
    string public name;
    string public symbol;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => uint8) public didPrimarySale; // Primary sale
    mapping(uint256 => uint256) public tokenByIndex;
    mapping(uint256 => string) public tokenURI;
    mapping(uint256 => Sale) public sale;
    mapping(bytes4 => bool) public supportsInterface; // eip-165 
    mapping(uint256 => address payable[]) public gRoyaltiesByTokenId; // gRoyaltiesByTokenId[tokenId][array of gRoyalties address]
    mapping(uint256 => uint256[]) public royaltiesByTokenId; // ownersRoyaltiesByTokenId[tokenId][array of royalties %]
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => mapping(uint256 => uint256)) public tokenOfOwnerByIndex;
    event Approval(address indexed approver, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed holder, address indexed operator, bool approved);
    event MolBankUpdated(address indexed _molBank);
    event MolFeesUpdated(uint256 indexed _molFees);
    event MolUpdated(address indexed _mol);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event UpdateSale(uint8 forSale, uint256 indexed ethPrice, uint256 indexed tokenId);
    struct Sale {
        uint8 forSale; // 0 = not on sale, 1 = on sale
        uint256 ethPrice;
    }
    constructor (string memory _name, string memory _symbol, string memory _gRoyaltiesURI) public {
        supportsInterface[0x80ac58cd] = true; // ERC721 
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
        name = _name;
        symbol = _symbol;
        creator = msg.sender;
        gRoyaltiesURI = _gRoyaltiesURI;
    }
    function approve(address spender, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/operator");
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId); 
    }
    function distributeRoyalties(uint256 _tokenId, uint256 _ethPrice) private returns (uint256){
        require(gRoyaltiesByTokenId[_tokenId].length == royaltiesByTokenId[_tokenId].length, "!ownersByTokenId/ownerRoyaltiesByTokenId");
        uint256 royaltyPayout;
        uint256 totalPayout = _ethPrice.div(100);
        for (uint256 i = 0; i < gRoyaltiesByTokenId[_tokenId].length; i++) {
            uint256 eachPayout;
            eachPayout = totalPayout.mul(royaltiesByTokenId[_tokenId][i]);
            royaltyPayout += eachPayout;
            (bool success, ) = address(uint160(gRoyaltiesByTokenId[_tokenId][i])).call.value(eachPayout)("");
            require(success, "!transfer");
        }
        return royaltyPayout;
    }
    function mint(uint8 forSale, uint256 ethPrice, string calldata _tokenURI) external { 
        totalSupply++;
        require(forSale <= 1, "!forSale value");
        require(totalSupply <= GAMMA_MAX, "maxed");
        uint256 tokenId = totalSupply;
        balanceOf[msg.sender]++;
        didPrimarySale[tokenId] = 0;
        // ownersByTokenId[tokenId].push(msg.sender); // push minter to owners registry per token Id
        ownerOf[tokenId] = msg.sender;
        royaltiesByTokenId[tokenId].push(startingRoyalties); // push royalties % of minter to royalties registry per token Id
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        tokenByIndex[tokenId - 1] = tokenId;
        tokenOfOwnerByIndex[msg.sender][tokenId - 1] = tokenId;
        tokenURI[tokenId] = _tokenURI;
        
        // mint royalties token and transfer to artist
        gRoyalties g = new gRoyalties();
        g.mint(Utilities.append(name, " Royalties Token"), gRoyaltiesURI);
        g.transfer(msg.sender, 1);
        gRoyaltiesByTokenId[tokenId].push(address(g));
        
        emit Transfer(address(0), msg.sender, tokenId); 
        emit UpdateSale(forSale, ethPrice, tokenId);
    }
    function purchase(uint256 tokenId) payable external {
        require(msg.value == sale[tokenId].ethPrice, "!ethPrice");
        require(msg.sender != ownerOf[tokenId], "owner"); 
        require(sale[tokenId].forSale == 1, "!forSale");
        if (didPrimarySale[tokenId] == 0) {
            (bool success, ) = ownerOf[tokenId].call.value(msg.value)("");
            require(success, "!transfer");
            didPrimarySale[tokenId] = 1;
        } else {
            uint256 molPayout = molFee.mul(sale[tokenId].ethPrice).div(100);
            uint256 royaltyPayout = distributeRoyalties(tokenId, msg.value);
            (bool success, ) = molBank.call.value(molPayout)("");
            require(success, "!transfer");
            uint256 ownerCut = sale[tokenId].ethPrice.sub(molPayout).sub(royaltyPayout);
            (success, ) = ownerOf[tokenId].call.value(ownerCut)("");
            require(success, "!transfer");            
        }
        _transfer(ownerOf[tokenId], msg.sender, tokenId);
        royaltiesByTokenId[tokenId].push(royaltiesByTokenId[tokenId][royaltiesByTokenId[tokenId].length.sub(1)].sub(1)); // push decayed royalties % to royalties registry per token Id
        
        // mint royalties token and transfer to artist
        gRoyalties g = new gRoyalties();
        g.mint(Utilities.append(name, " Royalties Token"), gRoyaltiesURI);
        g.transfer(creator, 1);
        gRoyaltiesByTokenId[tokenId].push(address(g));
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
    function updateSale(uint256 ethPrice, uint256 tokenId, uint8 forSale) external {
        require(msg.sender == ownerOf[tokenId], "!owner"); // Communal ownership
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        emit UpdateSale(forSale, ethPrice, tokenId);
    }

    /******************
    Mol LeArt Functions
    ******************/
    modifier onlyMol () {
        require(msg.sender == mol, "!Mol");
        _;
    }
    function molTransfer(address to, uint256 tokenId) public onlyMol {
        _transfer(ownerOf[tokenId], to, tokenId);
    }
    function updateMol(address payable _mol) public onlyMol {
        mol = _mol;
        emit MolUpdated(mol);
    }
    function updateMolBank(address payable _molBank) public onlyMol {
        molBank = _molBank;
        emit MolBankUpdated(molBank);
    }
    function updateMolFees(uint256 _molFee) public onlyMol {
        molFee = _molFee;
        emit MolFeesUpdated(molFee);
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
    function mint(string calldata _name, string calldata _tokenURI) external { 
        name = _name;
        // use totalSupply as tokenId
        balanceOf[msg.sender]++;
        ownerOf[totalSupply] = msg.sender;
        tokenByIndex[totalSupply - 1] = totalSupply;
        tokenURI[totalSupply] = _tokenURI;
        tokenOfOwnerByIndex[msg.sender][totalSupply - 1] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply); 
    }
    function purchase(uint256 tokenId) payable external {
        require(msg.value == sale[tokenId].ethPrice, "!ethPrice");
        require(sale[tokenId].forSale, "!forSale");
        (bool success, ) = ownerOf[tokenId].call.value(msg.value)("");
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
        (bool success, ) = msg.sender.call.value(address(this).balance)("");
        require(success, "!transfer");        
    }
    function() external payable {  require(msg.data.length ==0); }
}
