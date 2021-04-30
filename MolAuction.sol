pragma solidity ^0.6.0;
// SPDX-License-Identifier: GPL-3.0-or-later

interface ICommons {
    function dropCoin(address _recipient, uint256 _amount) external;
}

interface IGamma {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function getSale(uint256 tokenId) external returns (uint, uint, uint, address);
    function getOwnerOf(uint256 tokenId) external returns (address);
    function getRoyalties() external returns (uint256);
    function getRoyaltiesToken(uint256 tokenId) external returns (address);
}

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

contract MolAuction {
    using SafeMath for uint256;
    
    ICommons public commons;
    IGamma public gamma;

    uint256 public fee;
    
    struct auction {
        uint256 bid;
        uint256 reserve;
        address payable bidder;
        address creator;
        uint256 startBlock;
    }
    
    mapping(uint256 => auction) public auctions;
    
    // **************
    // EVENT TRACKING
    // **************
    event CreateAuction(uint256 tokenId, address indexed creator, uint256 reserve, uint256 createdAt);
    event UpdateAuctionReserve(uint256 reserve);
    event UpdateBid(uint256 bid, address indexed bidder);
    event WithdrawBid(uint256 tokenId);
    event AcceptBid(uint256 tokenId, uint256 price, address indexed buyer, address indexed creator);
    
    constructor (address payable _commons, address _gamma, uint256 _fee) public {
        commons = ICommons(_commons);
        gamma = IGamma(_gamma);
        fee = _fee;
    }
    
    function startAuction(uint256 _tokenId, uint256 _reserve) internal {
        auctions[_tokenId].creator = msg.sender;
        auctions[_tokenId].reserve = _reserve;
        auctions[_tokenId].startBlock = block.number;
    }
    
    function createAuction(uint256 _tokenId, uint256 _reserve) public {
        
        // Check ownership of NFT
        if (gamma.getOwnerOf(_tokenId) == address(commons)) {
            // Get creator of NFT
            (, , , address minter) = gamma.getSale(_tokenId);
            require(minter == msg.sender, '!minter');
            startAuction(_tokenId, _reserve);
        } else {
            require(gamma.getOwnerOf(_tokenId) == msg.sender, '!owner');
            startAuction(_tokenId, _reserve);
        }
        
        emit CreateAuction(_tokenId, auctions[_tokenId].creator, auctions[_tokenId].reserve, auctions[_tokenId].startBlock);
    }
    
    function updateAuctionReserve(uint256 _tokenId, uint256 _reserve) public {
        auctions[_tokenId].reserve = _reserve;
        
        emit UpdateAuctionReserve(auctions[_tokenId].reserve);
    }
    
    function bid(uint256 _tokenId, uint256 _airdropAmount) public payable {
        require(msg.value > auctions[_tokenId].bid, 'You must bid higher than the existing bid!');
        require(auctions[_tokenId].startBlock > 0, '!auction');
        
        (bool success, ) = auctions[_tokenId].bidder.call{value: auctions[_tokenId].bid}("");
        require(success, "!transfer");        
        
        auctions[_tokenId].bid = msg.value;
        auctions[_tokenId].bidder = msg.sender;
        
        commons.dropCoin(msg.sender, _airdropAmount);
        
        emit UpdateBid(msg.value, msg.sender);
    }
    
    function withdrawBid(uint256 _tokenId) public {
        require(msg.sender == auctions[_tokenId].bidder, 'No bids to withdraw!');
    
        (bool success, ) = auctions[_tokenId].bidder.call{value: auctions[_tokenId].bid}("");
        require(success, "!transfer");
        
        delete auctions[_tokenId].bid;
        delete auctions[_tokenId].bidder;
        
        emit WithdrawBid(_tokenId);
    }
    
    function acceptBid(uint256 _tokenId, uint256 _airdropAmount, address payable _beneficiary) public {
        require(msg.sender == auctions[_tokenId].creator, '!creator');
        
        uint256 price = auctions[_tokenId].bid;
        address payable buyer = auctions[_tokenId].bidder;
        
        auctions[_tokenId].bid = 0;
        auctions[_tokenId].bidder = address(0);        
        
        // Royalties 
        uint256 royalties = price.mul(gamma.getRoyalties()).div(100);
        address g = gamma.getRoyaltiesToken(_tokenId);
        (bool success, ) = g.call{value: royalties}("");
        require(success, "!transfer");
        
        // Fees to Commons
        uint256 feePayment = price.mul(fee).div(100);
        (success, ) = address(commons).call{value: feePayment}("");
        require(success, "!transfer");
        
        // Specified beneficiary takes the residual
        (success, ) = _beneficiary.call{value: price.sub(royalties).sub(feePayment)}("");
        require(success, "!transfer");
        
        gamma.transferFrom(gamma.getOwnerOf(_tokenId), buyer, _tokenId);
    
        commons.dropCoin(auctions[_tokenId].creator, _airdropAmount);
        
        emit AcceptBid(_tokenId, price, buyer, auctions[_tokenId].creator);
    }
}
