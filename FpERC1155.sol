// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./ExtendERC1155.sol";

contract FpERC1155 is ExtendERC1155, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    address public fpCoupon;
    mapping (address => EnumerableSet.UintSet) tokenIdHolders;

    modifier onlyFpCoupon() {
        require(msg.sender == fpCoupon, "only FpCoupon allowed");
        _;
    }

    constructor() public ExtendERC1155("") {
    }

        // 查询owner拥有的coupon id
    function getTokensListOf(address owner) public view returns(uint256[] memory) {
        uint256 len = tokenIdHolders[owner].length();
        uint256[] memory ids = new uint256[](len);
        for (uint i = 0; i < len; i++) {
            ids[i] = tokenIdHolders[owner].at(i);
        }
        return ids;
    }

    function setFpCoupon(address fp) public onlyOwner {
        fpCoupon = fp;
    }

    function setURI(string memory _uri) public onlyOwner {
        _setURI(_uri);
    }

    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) public onlyFpCoupon {
        _mint(to, tokenId, amount, data);
        tokenIdHolders[to].add(tokenId);
    }

    function burn(address from, uint256 tokenId, uint256 amount) public onlyFpCoupon {
        if (balanceOf(from, tokenId) == amount) {
            tokenIdHolders[from].remove(tokenId);
        }

        _burn(from, tokenId, amount);

    }

    function transfer(address from, address to, uint256 tokenId, uint256 amount) public onlyFpCoupon {
        tokenIdHolders[to].add(tokenId);
        if (balanceOf(from, tokenId) == amount) {
            tokenIdHolders[from].remove(tokenId);
        }

        _transfer(from, to, tokenId, amount);
    }

    function batchBalanceOf(address account, uint256[] memory tokenIds) public view returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](tokenIds.length);
        for (uint i = 0; i < tokenIds.length; i++) {
            amounts[i] = balanceOf(account, tokenIds[i]);
        }
        return amounts;
    }
}