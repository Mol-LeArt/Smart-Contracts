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
pragma experimental ABIEncoderV2;

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

contract MolGamma { // Γ - mv - NFT - mkt - γ
    using SafeMath for uint256;
    address public mol = 0xF09631d7BA044bfe44bBFec22c0A362c7e9DCDd8;
    address payable public molBank = 0xF09631d7BA044bfe44bBFec22c0A362c7e9DCDd8;
    uint256 public constant GAMMA_MAX = 5772156649015328606065120900824024310421;
    uint256 public molFee = 5;
    uint256 public startingRoyalties = 10;
    uint256 public totalSupply;
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
    mapping(uint256 => address payable[]) public ownersByTokenId; // ownersPerTokenId[tokenId][owner address]
    mapping(uint256 => uint256[]) public ownersRoyaltiesByTokenId; // ownerIndex[tokenId][Owner struct]
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
    constructor (string memory _name, string memory _symbol) public {
        supportsInterface[0x80ac58cd] = true; // ERC721 
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
        name = _name;
        symbol = _symbol;
    }
    function approve(address spender, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/operator");
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId); 
    }
    function distributeRoyalties(uint256 _tokenId, uint256 _ethPrice) private returns (uint256){
        require(ownersByTokenId[_tokenId].length == ownersRoyaltiesByTokenId[_tokenId].length, "!ownersByTokenId/ownerRoyaltiesByTokenId");
        uint256 royaltyPayout;
        uint256 totalPayout = _ethPrice.div(100);
        for (uint256 i = 0; i < ownersByTokenId[_tokenId].length; i++) {
            uint256 eachPayout;
            eachPayout = totalPayout.mul(ownersRoyaltiesByTokenId[_tokenId][i]);
            royaltyPayout += eachPayout;
            (bool success, ) = ownersByTokenId[_tokenId][i].call.value(eachPayout)("");
            require(success, "!transfer");
        }
        return royaltyPayout;
    }
    function getAllTokenURI() public view returns (string[] memory){
        string[] memory ret = new string[](totalSupply);
        for (uint i = 0; i < totalSupply; i++) {
            ret[i] = tokenURI[i.add(1)];
        }
        return ret;
    }
    function mint(uint8 forSale, uint256 ethPrice, string calldata _tokenURI) external { 
        totalSupply++;
        require(forSale <= 1, "!forSale value");
        require(totalSupply <= GAMMA_MAX, "maxed");
        uint256 tokenId = totalSupply;
        balanceOf[msg.sender]++;
        didPrimarySale[tokenId] = 0;
        ownersByTokenId[tokenId].push(msg.sender); // push minter to owners registry per token Id
        ownerOf[tokenId] = msg.sender;
        ownersRoyaltiesByTokenId[tokenId].push(startingRoyalties); // push royalties % of minter to royalties registry per token Id
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        tokenByIndex[tokenId - 1] = tokenId;
        tokenOfOwnerByIndex[msg.sender][tokenId - 1] = tokenId;
        tokenURI[tokenId] = _tokenURI;
        emit Transfer(address(0), msg.sender, tokenId); 
        emit UpdateSale(forSale, ethPrice, tokenId);
    }
    function purchase(uint256 tokenId) payable external {
        require(msg.value == sale[tokenId].ethPrice, "!ethPrice");
        require(msg.sender != ownerOf[tokenId], "owner"); // Communal ownership
        require(sale[tokenId].forSale == 1, "!forSale");
        address owner = ownerOf[tokenId];
        // Distribute ethPrice 
        if (didPrimarySale[tokenId] == 0) {
            (bool success, ) = owner.call.value(msg.value)("");
            require(success, "!transfer");
            didPrimarySale[tokenId] = 1;
        } else {
            uint256 molPayout = molFee.mul(sale[tokenId].ethPrice).div(100);
            uint256 royaltyPayout = distributeRoyalties(tokenId, msg.value);
            (bool success, ) = molBank.call.value(molPayout)("");
            require(success, "!transfer");
            uint256 ownerCut = sale[tokenId].ethPrice.sub(molPayout).sub(royaltyPayout);
            (success, ) = owner.call.value(ownerCut)("");
            require(success, "!transfer");            
        }
        _transfer(owner, msg.sender, tokenId);
        ownersByTokenId[tokenId].push(msg.sender); // push minter to owners registry per token Id
        ownersRoyaltiesByTokenId[tokenId].push(ownersRoyaltiesByTokenId[tokenId][ownersRoyaltiesByTokenId[tokenId].length.sub(1)].sub(1)); // push decayed royalties % to royalties registry per token Id
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
