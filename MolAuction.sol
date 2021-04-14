pragma solidity ^0.6.0;
// SPDX-License-Identifier: GPL-3.0-or-later

import './MolCommons.sol';

contract MolAuction {
    MolCommons public commons;
    GAMMA public gamma;
    LiteToken public coin;
    
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
    
    constructor (MolCommons _commons, GAMMA _gamma, LiteToken _coin) public {
        commons = _commons;
        gamma = _gamma;
        coin = _coin;
    }
    
    function createAuction(uint256 _tokenId, uint256 _reserve) public {
        require(commons.isCreator(msg.sender), '!creator');
        (, , , address minter) = gamma.getSale(_tokenId);
        require(minter == msg.sender, '!minter');
        auctions[_tokenId].creator = msg.sender;
        auctions[_tokenId].reserve = _reserve;
        auctions[_tokenId].startBlock = block.number;
        
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
        
        emit WithdrawBid(_tokenId);
    }
    
    function acceptBid(uint256 _tokenId, uint256 _airdropAmount) public {
        require(msg.sender == auctions[_tokenId].creator, '!creator');
        
        uint256 price = auctions[_tokenId].bid;
        address payable buyer = auctions[_tokenId].bidder;
        
        auctions[_tokenId].bid = 0;
        auctions[_tokenId].bidder = address(0);        
        
        (bool success, ) = auctions[_tokenId].creator.call{value: price}("");
        require(success, "!transfer");
        
        gamma.updateSale(0, 0, _tokenId, 0);
        gamma.transferFrom(address(commons), buyer, _tokenId);
        
        commons.dropCoin(auctions[_tokenId].creator, _airdropAmount);
        
        emit AcceptBid(_tokenId, price, buyer, auctions[_tokenId].creator);
    }
    
    // function airdrop(address _recipient, uint256 _amount) public {
    //     commons.dropCoin(_recipient, _amount);
    // }
}
