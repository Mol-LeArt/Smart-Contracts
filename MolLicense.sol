pragma solidity ^0.6.0;
// SPDX-License-Identifier: GPL-3.0-or-later

import './MolCommons.sol';

contract MolLicense {
    using SafeMath for uint256;
    
    MolCommons public commons;
    GAMMA public gamma;
    LiteToken public coin;
    
    uint public licenseId;
    uint256 public fee;

    struct license {
        uint8[] rights; // [digital use, print runs, media, templates, merchandise, decor, advertising]
        uint256[] ethPrice; // ethPrice for [small, medium, large] usecase
        uint256[] coinPrice; // coinPrice for [small, medium, large] usecase
        uint256 startBlock;
    }
    
    struct licensed {
        uint256 tokenId;
        uint8 active;
        uint8[] licensedRights;
        uint8 currency; // 0 - eth, 1 - coin
        address licensee;
        string detail;
    }
    
    mapping(uint256 => license) public licenses;
    mapping(uint256 => licensed) public licensedActivities;
    
    // **************
    // EVENT TRACKING
    // **************
    event CreateLicense(uint256 tokenId, uint8[] indexed rights, uint256[] indexed ethPrice, uint256[] indexed coinPrice, uint256 createdAt);
    event UpdateLicense(uint256 tokenId, uint8[] indexed rights, uint256[] indexed ethPrice, uint256[] indexed coinPrice);
    event GetLicensed(uint256 licenseId, uint256 tokenId, uint8 active, uint8[] indexed rights, uint8 currency, uint256 sum, address licensee);
    event RevokeLicense(uint licenseId, string detail);

    constructor (MolCommons _commons, GAMMA _gamma, LiteToken _coin, uint256 _fee) public {
        commons = _commons;
        gamma = _gamma;
        coin = _coin;
        fee = _fee;
    }
    
    function createLicense(uint256 _tokenId, uint8[] memory _rights, uint256[] memory _ethPrice, uint256[] memory _coinPrice, uint256 _airdropAmount) public {
        require(getMinter(_tokenId) == msg.sender, '!minter');
        licenses[_tokenId].rights = _rights;
        licenses[_tokenId].ethPrice = _ethPrice;
        licenses[_tokenId].coinPrice = _coinPrice;
        licenses[_tokenId].startBlock = block.number;
        
        commons.dropCoin(msg.sender, _airdropAmount);
        
        emit CreateLicense(_tokenId, licenses[_tokenId].rights, licenses[_tokenId].ethPrice, licenses[_tokenId].coinPrice, licenses[_tokenId].startBlock);
    }
    
    function updateLicense(uint256 _tokenId, uint8[] memory _rights, uint256[] memory _ethPrice, uint256[] memory _coinPrice) public {
        require(getMinter(_tokenId) == msg.sender, '!minter');
        require(licenses[_tokenId].startBlock > 0, '!license');
        licenses[_tokenId].rights = _rights;
        licenses[_tokenId].ethPrice = _ethPrice;
        licenses[_tokenId].coinPrice = _coinPrice;
        
        emit UpdateLicense(_tokenId, licenses[_tokenId].rights, licenses[_tokenId].ethPrice, licenses[_tokenId].coinPrice);
    }
    
    function getLicensed(uint256 _tokenId, uint8[] memory _rights, uint8 _currency, uint8 _usecase, uint256 _airdropAmount) public payable {
        licenseId++;
        require(licenses[_tokenId].startBlock > 0, '!license');
        require(_rights.length == licenses[_tokenId].rights.length, 'Rights do not match!');
        uint numOfRights;
        uint payment;
        
        licensedActivities[licenseId].tokenId = _tokenId;
        licensedActivities[licenseId].licensedRights = _rights;
        licensedActivities[licenseId].currency = _currency;
        licensedActivities[licenseId].licensee = msg.sender;
        
        for (uint i = 0; i < licenses[_tokenId].rights.length; i++) {
            if (_rights[i] == 1 && licenses[_tokenId].rights[i] == 1) {
                numOfRights++;
            } else {
                continue;
            }
        }
        
        if (_currency == 0) {
            payment = numOfRights.mul(licenses[_tokenId].ethPrice[_usecase]);
            require(msg.value == (payment.add(payment.mul(fee).div(100))), '!payment');
            
            // Commons takes a % of licensing fee
            (bool success, ) = address(commons).call{value: payment.mul(fee).div(100)}("");
            require(success, "!transfer");
            
            // Minter of NFT takes licensing fee
            (success, ) = getMinter(_tokenId).call{value: payment}("");
            require(success, "!transfer");
            
            // Update license activity
            licensedActivities[licenseId].active = 1;
        } else if (_currency == 1 && coin.transferable()) {
            payment = numOfRights.mul(licenses[_tokenId].coinPrice[_usecase]);
            coin.transferFrom(msg.sender, getMinter(_tokenId), payment);
            
            // Update license activity
            licensedActivities[licenseId].active = 1;
        } else if (_currency == 1 && !coin.transferable()) {
            payment = numOfRights.mul(licenses[_tokenId].coinPrice[_usecase]);
            
            coin.updateTransferability(true);
            coin.transferFrom(msg.sender, getMinter(_tokenId), payment);
            coin.updateTransferability(false);
            
            // Update license activity
            licensedActivities[licenseId].active = 1;
        } else {
            revert('Something wrong!');
        }
        
        commons.dropCoin(msg.sender, _airdropAmount);
        emit GetLicensed(
            licenseId, 
            licensedActivities[licenseId].tokenId, 
            licensedActivities[licenseId].active,
            licensedActivities[licenseId].licensedRights, 
            licensedActivities[licenseId].currency,
            payment, 
            licensedActivities[licenseId].licensee);
    }

    function revokeLicense(uint256 _tokenId, uint _licenseId, string memory _detail) public {
        require(getMinter(_tokenId) == msg.sender, '!minter');
    
        licensedActivities[_licenseId].active = 0;
        licensedActivities[_licenseId].detail = _detail;
        
        emit RevokeLicense(_licenseId, _detail);
    }
    
    function getMinter(uint _tokenId) internal view returns (address) {
        (, , , address minter) = gamma.getSale(_tokenId);
        return minter;
    }
}
