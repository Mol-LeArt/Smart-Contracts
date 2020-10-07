/**
 *Submitted for verification at Etherscan.io on 2020-09-17
*/

pragma solidity 0.5.17;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract MolGamma { // Γ - mv - NFT - mkt - γ
    using SafeMath for uint256;
    address payable public molBank = 0xF09631d7BA044bfe44bBFec22c0A362c7e9DCDd8;
    address public mol = 0xF09631d7BA044bfe44bBFec22c0A362c7e9DCDd8;
    uint256 public constant GAMMA_MAX = 5772156649015328606065120900824024310421;
    uint256 public totalSupply;
    uint256 public startingRoyalties = 10;
    uint256 public molFee = 5;
    string public name = "GAMMA";
    string public symbol = "GAMMA";
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public coOwnerOf;   // Communal ownership
    mapping(uint256 => uint8) public didPrimarySale; // Primary sale
    mapping(uint256 => uint256) public tokenByIndex;
    mapping(uint256 => string) public tokenURI;
    mapping(uint256 => Sale) public sale;
    mapping(bytes4 => bool) public supportsInterface; // eip-165
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => mapping(uint256 => uint256)) public tokenOfOwnerByIndex;
    mapping(uint256 => uint256[]) public ownersRoyaltiesByTokenId; // ownerIndex[tokenId][Owner struct]
    mapping(uint256 => address payable[]) public ownersByTokenId; // ownersPerTokenId[tokenId][owner address]
    event Approval(address indexed approver, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event UpdateSale(uint256 indexed ethPrice, uint256 indexed tokenId, bool forSale);
    event MolFeesUpdated(uint256 indexed _molFees);
    event MolBankUpdated(address indexed _molBank);
    event MolUpdated(address indexed _mol);
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
    function mint(uint256 ethPrice, string calldata _tokenURI, bool forSale, address payable coCreator) external {
        totalSupply++;
        require(totalSupply <= GAMMA_MAX, "maxed");
        uint256 tokenId = totalSupply;
        balanceOf[msg.sender]++;
        ownerOf[tokenId] = msg.sender;
        didPrimarySale[tokenId] = 0;
        coOwnerOf[tokenId] = coCreator; // Communal ownership
        ownersByTokenId[tokenId].push(msg.sender); // push minter to owners registry per token Id
        ownersByTokenId[tokenId].push(coCreator); // push coCreator to owners registry per token Id
        ownersRoyaltiesByTokenId[tokenId].push(startingRoyalties); // push royalties % of minter to royalties registry per token Id
        ownersRoyaltiesByTokenId[tokenId].push(startingRoyalties); // push royalties % of co-creator to royalties registry per token Id
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
        require(sale[tokenId].forSale, "!forSale");
        address owner = ownerOf[tokenId];

        // Distribute ethPrice
        if (didPrimarySale[tokenId] == 0) {
            (bool success, ) = owner.call.value(msg.value)("");
            require(success, "!transfer");
            didPrimarySale[tokenId] = 1;
        } else {
            uint256 royaltyPayout = distributeRoyalties(tokenId, msg.value);
            uint256 molPayout = (molFee * sale[tokenId].ethPrice).div(100);
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
        sale[tokenId].forSale = false;
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
    function updateSale(uint256 ethPrice, uint256 tokenId, bool forSale) payable external {
        require(msg.sender == ownerOf[tokenId], "!owner"); // Communal ownership
        sale[tokenId].ethPrice = ethPrice;
        sale[tokenId].forSale = forSale;
        emit UpdateSale(ethPrice, tokenId, forSale);
    }
    function distributeRoyalties(uint256 _tokenId, uint256 _ethPrice) private returns (uint256){
        require(ownersByTokenId[_tokenId].length == ownersRoyaltiesByTokenId[_tokenId].length, "!ownersByTokenId/ownerRoyaltiesByTokenId");
        uint256 totalPayout = _ethPrice.div(100);
        uint256 royaltyPayout;

        for (uint256 i = 0; i < ownersByTokenId[_tokenId].length; i++) {
            uint256 eachPayout;
            eachPayout = totalPayout.mul(ownersRoyaltiesByTokenId[_tokenId][i]);
            royaltyPayout += eachPayout;
            (bool success, ) = ownersByTokenId[_tokenId][i].call.value(eachPayout)("");
            require(success, "!transfer");
        }
        return royaltyPayout;
    }

    /***************
    Mol LeArt Functions
    ***************/
    modifier onlyMol () {
        require(msg.sender == mol, "caller not lexDAO");
        _;
    }
    function updateMolFees(uint256 _molFee) public onlyMol {
        molFee = _molFee;
        emit MolFeesUpdated(molFee);
    }
    function updateMolBank(address payable _molBank) public onlyMol {
        molBank = _molBank;
        emit MolBankUpdated(molBank);
    }
    function updateMol(address payable _mol) public onlyMol {
        mol = _mol;
        emit MolUpdated(mol);
    }
    function molTransfer(address to, uint256 tokenId) public onlyMol {
        _transfer(ownerOf[tokenId], to, tokenId);
    }
}
