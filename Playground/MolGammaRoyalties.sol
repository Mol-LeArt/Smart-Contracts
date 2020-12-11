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
    // uint256 public casinoWarPrice;
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
    constructor (string memory _name, string memory _symbol) public {
        supportsInterface[0x80ac58cd] = true; // ERC721
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
        name = _name;
        symbol = _symbol;
        creator = msg.sender;
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
    function mint(uint8 forSale, uint256 ethPrice, string calldata _tokenURI, string calldata _gRoyaltiesURI) external {
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
        gRoyaltiesURI = _gRoyaltiesURI;
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
        // ownersByTokenId[tokenId].push(msg.sender); // push minter to owners registry per token Id
        royaltiesByTokenId[tokenId].push(royaltiesByTokenId[tokenId][royaltiesByTokenId[tokenId].length.sub(1)].sub(1)); // push decayed royalties % to royalties registry per token Id

        // mint royalties token and transfer to artist
        gRoyalties g = new gRoyalties();
        g.mint(Utilities.append(name, " Royalties Token"), gRoyaltiesURI);
        g.transfer(msg.sender, 1);
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
    // function payRoyalties() external payable {
    //     (bool success, ) = address(uint160(royaltiesContract[0])).call.value(msg.value)("");
    //     require(success, "!transfer");
    // }
    function mintDashboard() external payable returns (address) {
        require(msg.sender == creator, "!creator");
        gDashboard g = new gDashboard(Utilities.append(name, " Dashboard Token"), creator);
        g.mint(1, "asdfas", true);
        g.transfer(msg.sender, 1);
    }
    // function casinoWarArtist(address tokenAddress, uint256 tokenId, uint256 price) external {
    //   require(artist == msg.sender, "!artist");
    //   require(ERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "!owner");
    //   ERC721(tokenAddress).transferFrom(msg.sender, address(this), tokenId);

    //   casinoWarPrice = price;
    // }
    // function casinoWar(address payable _gRoyaltiesAddress, uint256 tokenId, uint8 bet) external {
    //     require(gRoyalties(_gRoyaltiesAddress).ownerOf(1) == msg.sender, "!owner");
    //     if (sale[tokenId].ethPrice > price && bet == 1) {
    //         ERC721(tokenAddress).transferFrom(msg.sender, address(this), tokenId);
    //     }
    // }

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
contract gDashboard { // Γ - mv - NFT - mkt - γ
    using SafeMath for uint256;
    address payable public owner;
    uint256 public dashboardId = 1;
    string public name;
    string public symbol = "gDashboard";
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
    constructor(string memory _name, address payable _owner) public {
        supportsInterface[0x80ac58cd] = true; // ERC721
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
        name = _name;
        owner = _owner;
    }
    function approve(address spender, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/operator");
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId);
    }
    function mint(uint256 ethPrice, string calldata _tokenURI, bool forSale) external {
        balanceOf[msg.sender]++;
        ownerOf[dashboardId] = msg.sender;
        tokenByIndex[dashboardId - 1] = dashboardId;
        tokenURI[dashboardId] = _tokenURI;
        sale[dashboardId].ethPrice = ethPrice;
        sale[dashboardId].forSale = forSale;
        tokenOfOwnerByIndex[msg.sender][dashboardId - 1] = dashboardId;
        emit Transfer(address(0), msg.sender, dashboardId);
        emit UpdateSale(ethPrice, dashboardId, forSale);
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
    function updateOwner(address payable _owner) external {
        require(msg.sender == owner, "!dao");
        owner = _owner;
    }
    function updateSale(uint256 ethPrice, uint256 tokenId, bool forSale) payable external {
        require(msg.sender == ownerOf[tokenId], "!owner");
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        // (bool success, ) = dao.call.value(msg.value)("");
        // require(success, "!transfer");
        emit UpdateSale(ethPrice, tokenId, forSale);
    }
    function withdraw() payable public {
        (bool success, ) = msg.sender.call.value(address(this).balance)("");
        require(success, "!transfer");
    }
    function mintLicense() external payable returns (address) {
        require(msg.sender == owner, "!creator");
        gLicense g = new gLicense(Utilities.append(name, " License Token"), owner);
        g.mint(1, "asdfas", true);
        g.transfer(msg.sender, 1);
    }
    function() external payable { require(msg.data.length ==0); }
}

contract gLicense { // Γ - mv - NFT - mkt - γ
    using SafeMath for uint256;
    // address payable public dao = 0x057e820D740D5AAaFfa3c6De08C5c98d990dB00d;
    address payable public licensor;
    uint256 public constant GAMMA_MAX = 5772156649015328606065120900824024310421;
    uint256 public totalSupply;
    string public name;
    string public symbol = "gLicense";
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

    //***** License *****//
    struct License {
        // license details set by original owner
        address licensee;
        uint256 licenseFee;
        string licenseDocument;
        uint8 licensePeriodLength; // Number of periodDuration a license will last

        // time related license data
        uint256 licenseStartTime;
        uint256 licenseEndTime;
        uint8 licensePeriodLengthReached; // 1 = reached, 0 = not reached

        // license results
        uint8 licenseOffered; // 1 = offer active, 0 = offer inactive
        uint8 licenseCompleted; // 1 = license completed, 0 = license incomplete
        uint8 licenseTerminated; // 1 = license terminated, 0 = license not terminated
        string licenseReport; // Licensee submits license report to complete active license
        string terminationDetail; // Mintor-owner submits termination detail to terminate an active license
    }
    uint256 public periodDuration = 86400; // default = 1 day (or 86400 seconds)

    uint8 public licenseCount = 0; // total license created
    mapping(uint256 => License) public licenses; // a dictionary of licenses

    constructor (string memory _name, address payable _licensor) public {
        supportsInterface[0x80ac58cd] = true; // ERC721
        supportsInterface[0x5b5e139f] = true; // METADATA
        supportsInterface[0x780e9d63] = true; // ENUMERABLE
        name = _name;
        licensor = _licensor;
    }
    function approve(address spender, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId] || isApprovedForAll[ownerOf[tokenId]][msg.sender], "!owner/operator");
        getApproved[tokenId] = spender;
        emit Approval(msg.sender, spender, tokenId);
    }
    function mint(uint256 ethPrice, string calldata _tokenURI, bool forSale) external {
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

        // license token business logic
        // x% up front (1-x)% upon completion
        // burn when license completed / terminated


        emit Transfer(address(0), msg.sender, tokenId);
        emit UpdateSale(ethPrice, tokenId, forSale);
    }
    function purchase(uint256 tokenId) payable external {
        require(msg.value == sale[tokenId].ethPrice, "!ethPrice");
        require(sale[tokenId].forSale, "!forSale");
        address owner = ownerOf[tokenId];
        (bool success, ) = owner.call.value(msg.value)("");
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
    // function updateDao(address payable _dao) external {
    //     require(msg.sender == dao, "!dao");
    //     dao = _dao;
    // }
    function updateSale(uint256 ethPrice, uint256 tokenId, bool forSale) payable external {
        require(msg.sender == ownerOf[tokenId], "!owner");
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        // (bool success, ) = dao.call.value(msg.value)("");
        // require(success, "!transfer");
        emit UpdateSale(ethPrice, tokenId, forSale);
    }
    function withdraw() payable public {
        (bool success, ) = msg.sender.call.value(address(this).balance)("");
        require(success, "!transfer");
    }

    // creator can create license accepted only by designated licensee
    function createLicense(
        address _licensee,
        uint256 _licenseFee,
        string memory _licenseDocument,
        uint8 _licensePeriodLength) public {
        require(msg.sender == licensor, "!licensor");
        require(_licensee != licensor, "licensee != licensor");
        require(_licensee != address(0), "licensee == address(0)");
        require(_licensePeriodLength != 0, "license period == 0");

        License memory license = License({
            licensee : _licensee,
            licenseFee : _licenseFee,
            licenseDocument : _licenseDocument,
            licensePeriodLength : _licensePeriodLength,
            licenseStartTime : 0,
            licenseEndTime : 0,
            licensePeriodLengthReached : 0,
            licenseOffered : 1,
            licenseCompleted : 0,
            licenseTerminated : 0,
            licenseReport : "",
            terminationDetail : ""
        });

        licenses[licenseCount] = license;
        // emit LicenseCreated(licenses[licenseCount].licensee, licenses[licenseCount].licenseDocument, licenses[licenseCount].licensePeriodLength, licenses[licenseCount].licenseStartTime);

        licenseCount += 1;
    }

    // designated licensee can accept license
    function acceptLicense(uint256 _licenseCount) public payable {
        require(msg.sender == licenses[_licenseCount].licensee, "Not licensee!");
        require(msg.value == licenses[_licenseCount].licenseFee, "Licensee fee incorrect!");
        require(licenses[_licenseCount].licenseOffered == 1, "Cannot accept offer never created or already claimed!");

        // record time of acceptance... maybe connect LexGrow for escrow?
        licenses[_licenseCount].licenseStartTime = now;

        // license contract formed and so license offer is no longer active
        licenses[_licenseCount].licenseOffered = 0;

        // licensee pays licensee fee
        licensor.transfer(msg.value);
    }

    // licensee can complete active licenses
    function completeLicense(uint256 _licenseCount, string memory _licenseReport) public payable {
        require(msg.sender == licenses[_licenseCount].licensee, "Not licensee!");
        require(msg.value > 0, "Cannot complete a license without paying!"); // is this needed??????????
        require(licenses[_licenseCount].licenseOffered == 0, "Cannot complete a license that is pending acceptance!");
        require(licenses[_licenseCount].licenseTerminated == 0, "Cannot complete a license that has been terminated!");

        licenses[_licenseCount].licenseReport = _licenseReport;
        licensor.transfer(msg.value);
        licenses[_licenseCount].licenseCompleted = 1;
        licenses[_licenseCount].licenseEndTime = now;

        // Record whether the license has lapsed
        getCurrentPeriod(_licenseCount) > licenses[_licenseCount].licensePeriodLength ? licenses[_licenseCount].licensePeriodLengthReached = 1 : licenses[_licenseCount].licensePeriodLengthReached = 0;
    }

    // creator can terminate active licenses
    function terminateLicense(uint256 _licenseCount, string memory _terminationDetail) public {
        require(msg.sender == licensor, "You are not the creator!");
        require(licenses[_licenseCount].licensee != address(0), "License does not have a licensee!");
        require(licenses[_licenseCount].licenseOffered == 0, "Cannot terminate a license not accepted by licensee!");
        require(licenses[_licenseCount].licenseCompleted == 0, "Cannot terminate a license that has been completed!");

        licenses[_licenseCount].terminationDetail = _terminationDetail;
        licenses[_licenseCount].licenseTerminated = 1;
        licenses[_licenseCount].licenseEndTime = now;

        // Record whether the license has lapsed
        getCurrentPeriod(_licenseCount) > licenses[_licenseCount].licensePeriodLength ? licenses[_licenseCount].licensePeriodLengthReached = 1 : licenses[_licenseCount].licensePeriodLengthReached = 0;
    }

    function getCurrentPeriod(uint256 _licenseCount) public view returns (uint256) {
        return now.sub(licenses[_licenseCount].licenseStartTime).div(periodDuration);
    }

    function() external payable { require(msg.data.length ==0); }
}
